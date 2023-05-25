# openssl을 이용한 자체서명인증서 생성

## Self Sign Certificate
Self Signed Certificate 란 스스로 서명한 인증서, 보통의 인증서는 개인키와 공개키가 쌍을 이루어 만들어진 다음 공개키를 인증기관의 개인키로 전자서명을 한 것을 인증서라고 함.

## 작업순서
1. Root CA 생성
2. SSL 인증서 발급을 위한 개인키 생성
3. SSL 인증서 발급
4. 발급된 인증서를 kubernetes secret로 생성
5. istio 적용

## Root CA 생성
1. rsa키 생성  
```bash
openssl genrsa -aes256 -out haiqv-rootca.key 2048
```
AES-256 비트로 암호화된 haiqv-rootca.key 라는 개인키 파일을 생성  
암호입력이 필요  

2. CSR생성을 위한 conf 작성  
```
# haiqv-rootca.conf

[ req ]
default_bits            = 2048
default_md              = sha1
default_keyfile         = haiqv-rootca.key
distinguished_name      = req_distinguished_name
extensions              = v3_ca
req_extensions          = v3_ca
 
[ v3_ca ]
basicConstraints       = critical, CA:TRUE, pathlen:0
subjectKeyIdentifier   = hash
keyUsage               = keyCertSign, cRLSign
nsCertType             = sslCA, emailCA, objCA
[req_distinguished_name ]
countryName                     = Country Name (2 letter code)
countryName_default             = KR
countryName_min                 = 2
countryName_max                 = 2

# 회사명 입력
organizationName              = Organization Name (eg, company)
organizationName_default      = Hanwha Vision

# SSL 서비스할 domain 명 입력
commonName                      = Common Name (eg, your name or your server's hostname)
commonName_default              = hanwha Self Signed CA
commonName_max                  = 64
```

3. CSR 생성
```bash
openssl req -new -key haiqv-rootca.key -out haiqv-rootca.csr -config haiqv-rootca.conf
```

4. 인증서 생성
```bash
# 기간 10년

openssl x509 -req \
-days 3650 \
-extensions v3_ca \
-set_serial 1 \
-in haiqv-rootca.csr \
-signkey haiqv-rootca.key \
-out haiqv-rootca.crt \
-extfile haiqv-rootca.conf
```

키생성 -> conf -> csr생성 -> 인증서 생성 순서

- haiqv-rootca.key: Root CA 개인키
- haiqv-rootca.crt: Root CA 공개키


## SSL 인증서에 사용할 RSA 개인키 생성
1. 키생성
```bash
openssl genrsa -aes256 -out haiqv.ai.key 2048
```
2. Key 에서 암호를 제거
```bash
mv haiqv.ai.key haiqv.ai.key.enc
openssl rsa -in haiqv.ai.key.enc -out haiqv.ai.key
```

## SSL 인증서 발급
1. CSR생성을 위한 conf 작성
```
# haiqv.ai.conf

[ req ]
default_bits            = 2048
default_md              = sha1
default_keyfile         = haiqv-rootca.key
distinguished_name      = req_distinguished_name
extensions              = v3_user

[ v3_user ]
basicConstraints = CA:FALSE
authorityKeyIdentifier = keyid,issuer
subjectKeyIdentifier = hash
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth,clientAuth
subjectAltName          = @alt_names
[ alt_names]
DNS.1   = *.haiqv.ai
DNS.2   = haiqv.ai

[req_distinguished_name ]
countryName                     = Country Name (2 letter code)
countryName_default             = KR
countryName_min                 = 2
countryName_max                 = 2

# 회사명 입력
organizationName              = Organization Name (eg, company)
organizationName_default      = Hanwha Vision

# 부서 입력
organizationalUnitName          = Organizational Unit Name (eg, section)
organizationalUnitName_default  = HAiQV AI Lab

# SSL 서비스할 domain 명 입력
commonName                      = Common Name (eg, your name or your server's hostname)
commonName_default              = haiqv.ai
commonName_max                  = 64
```

2. CSR 파일 생성
```bash
openssl req -new -key haiqv.ai.key -out haiqv.ai.csr -config haiqv.ai.conf
```

3. haiqv용 SSL 인증서를 rootCA로 서명하여 발급
```bash
openssl x509 -req -days 1825 -extensions v3_user -in haiqv.ai.csr \
-CA haiqv-rootca.crt -CAcreateserial \
-CAkey  haiqv-rootca.key \
-out haiqv.ai.crt -extfile haiqv.ai.conf
```

## kubernetes resource로 생성
```bash
kubectl create secret tls tls-secret --key="haiqv.ai.key" --cert="haiqv.ai.crt" -n kubeflow
```

## istio에 적용
gateway resource에 적용
```bash
kubectl edit gw kubeflow-gateway -n kubeflow
```

```yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: kubeflow-gateway
  namespace: kubeflow
spec:
  selector:
    istio: ingressgateway
  servers:
  - hosts:
    - '*'
    - haiqv.ai
    port:
      name: http
      number: 80
      protocol: HTTP
    tls:
      httpsRedirect: true
  # 추가
  - hosts:
    - haiqv.ai
    port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: tls-secret
  # 끝
```

---
nginx-ingress-controller Deployment YAML 파일에서 
args 필드에 --tcp-services-configmap 옵션을 추가

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-ingress-controller
  namespace: ingress-nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-ingress
  template:
    metadata:
      labels:
        app: nginx-ingress
    spec:
      containers:
      - name: nginx-ingress-controller
        image: k8s.gcr.io/ingress-nginx/controller:v1.1.0
        args:
        - /nginx-ingress-controller
        - --publish-service=$(POD_NAMESPACE)/nginx-ingress-controller
        - --election-id=ingress-controller-leader
        - --ingress-class=nginx
        - --configmap=$(POD_NAMESPACE)/nginx-ingress-controller
        - --tcp-services-configmap=ingress-nginx/tcp-services # 이 부분 추가
        - --validating-webhook=:8443
        - --validating-webhook-certificate=/usr/local/certificates/cert
        - --validating-webhook-key=/usr/local/certificates/key
        - --default-ssl-certificate=default/ssl-cert
```



FROM alpine
RUN apk update && apk add samba
RUN addgroup -S samba && adduser -S sunbean -G samba && echo -e "root\nroot" | smbpasswd -a -s sunbean
COPY smb.conf /etc/samba/
CMD ["smbd", "-F", "--no-process-group"]
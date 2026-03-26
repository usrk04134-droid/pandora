FROM registry.gitlab.com/esab/abw/plc/aws-platform/aws-platform-env:1.0.0

ARG UNAME="root"

USER root

RUN /bin/bash -c 'if [[ "$UNAME" != "root" ]] ; then usermod -md /home/${UNAME} -l ${UNAME} vscode; groupmod -n ${UNAME} vscode ; fi'

COPY extensions.zip /tmp/extensions.zip

RUN user_home="$(getent passwd "$UNAME" | cut -d: -f6)" \
	&& mkdir -p "$user_home/.vscode-server/extensions" \
	&& unzip /tmp/extensions.zip -d "$user_home/.vscode-server/extensions" \
	&& chown -R "$UNAME:$UNAME" "$user_home/.vscode-server" \
	&& rm -f /tmp/extensions.zip

USER $UNAME

CMD ["/bin/bash"]

FROM registry.access.redhat.com/ubi8/s2i-core:1

# RHSCL rh-nginx116 image.

EXPOSE 8080
EXPOSE 8443

ENV NAME=nginx \
    VERSION=0

ENV SUMMARY="Platform for running nginx  or building nginx-based application" \
    DESCRIPTION="Nginx is a web server and a reverse proxy server for HTTP, SMTP, POP3 and IMAP \
protocols, with a strong focus on high concurrency, performance and low memory usage. The container \
image provides a containerized packaging of the nginx  daemon. The image can be used \
as a base image for other applications based on nginx  web server. \
Nginx server image can be extended using source-to-image tool."

LABEL summary="${SUMMARY}" \
      description="${DESCRIPTION}" \
      io.k8s.description="${DESCRIPTION}" \
      io.k8s.display-name="Nginx" \
      io.openshift.expose-services="8080:http" \
      io.openshift.expose-services="8443:https" \
      io.openshift.tags="builder,${NAME},${NAME}-${NGINX_SHORT_VER}" \
      com.redhat.component="${NAME}-${NGINX_SHORT_VER}-container" \
      name="rhel8/${NAME}-${NGINX_SHORT_VER}" \
      version="1" \
      com.redhat.license_terms="https://www.redhat.com/en/about/red-hat-end-user-license-agreements#rhel" \
      maintainer="SoftwareCollections.org <sclorg@redhat.com>" \
      help="For more information visit https://github.com/sclorg/${NAME}-container" \
      usage="s2i build <SOURCE-REPOSITORY> rhel8/${NAME}-${NGINX_SHORT_VER}:latest <APP-NAME>"

ENV NGINX_CONFIGURATION_PATH=${APP_ROOT}/etc/nginx.d \
    NGINX_CONF_PATH=/etc/nginx/nginx.conf \
    NGINX_DEFAULT_CONF_PATH=${APP_ROOT}/etc/nginx.default.d \
    NGINX_CONTAINER_SCRIPTS_PATH=/usr/share/container-scripts/nginx \
    NGINX_APP_ROOT=${APP_ROOT} \
    NGINX_LOG_PATH=/var/log/nginx

RUN yum -y module enable nginx && \
    INSTALL_NGINX_PKGS="nss_wrapper bind-utils gettext hostname nginx nginx-mod-stream" && \
    yum install -y --setopt=tsflags=nodocs $INSTALL_NGINX_PKGS && \
    rpm -V $INSTALL_NGINX_PKGS && \
    yum -y clean all --enablerepo='*'


# Install node
ENV NODEJS_VERSION=12 \
    NPM_RUN=start \
    NPM_CONFIG_PREFIX=$HOME/.npm-global \
    PATH=$HOME/node_modules/.bin/:$HOME/.npm-global/bin/:$PATH    

RUN yum -y module reset nodejs && yum -y module enable nodejs:$NODEJS_VERSION && \
    INSTALL_NPM_PKGS="nodejs npm nodejs-nodemon nss_wrapper" && \
    ln -s /usr/lib/node_modules/nodemon/bin/nodemon.js /usr/bin/nodemon && \
    yum remove -y $INSTALL_NPM_PKGS && \
    yum install -y --setopt=tsflags=nodocs $INSTALL_NPM_PKGS && \
    yum install -y python3 && \
    rpm -V $INSTALL_NPM_PKGS && \
    yum -y clean all --enablerepo='*'


# Copy the S2I scripts from the specific language image to $STI_SCRIPTS_PATH
COPY ./s2i/bin/ $STI_SCRIPTS_PATH
# Copy extra files to the image.
COPY ./root/ /


# In order to drop the root user, we have to make some directories world
# writeable as OpenShift default security model is to run the container under
# random UID.
RUN sed -i -f ${NGINX_APP_ROOT}/nginxconf-fed.sed ${NGINX_CONF_PATH} && \
    chmod a+rwx ${NGINX_CONF_PATH} && \
    mkdir -p ${NGINX_APP_ROOT}/etc/nginx.d/ && \
    mkdir -p ${NGINX_APP_ROOT}/etc/nginx.default.d/ && \
    mkdir -p ${NGINX_APP_ROOT}/src/nginx-start/ && \
    mkdir -p ${NGINX_CONTAINER_SCRIPTS_PATH}/nginx-start && \
    mkdir -p ${NGINX_LOG_PATH} && \
    chmod -R a+rwx ${NGINX_APP_ROOT}/etc && \
    chmod -R a+rwx /var/lib/nginx && \
    chmod -R a+rwx ${NGINX_CONTAINER_SCRIPTS_PATH}/nginx-start && \
    chown -R 1001:0 ${NGINX_APP_ROOT} && \
    chown -R 1001:0 /var/lib/nginx && \
    chown -R 1001:0 ${NGINX_CONTAINER_SCRIPTS_PATH}/nginx-start && \
    # FIXME: Not sure if this is safe to do, just a hack to make the image work
    #chmod -R a+rwx /var/run && \
    #chown -R 1001:0 /var/run && \
    rpm-file-permissions
    
RUN touch /run/nginx.pid
RUN chgrp -R 1001 /run/nginx.pid \
  && chmod -R 777 /run/nginx.pid

RUN chown -R 1001:0 /usr/libexec/s2i/ && \
    chmod -R 777 /usr/libexec/s2i/    

USER 1001

# Not using VOLUME statement since it's not working in OpenShift Online:
# https://github.com/sclorg/httpd-container/issues/30
# VOLUME ["/usr/share/nginx/html"]
# VOLUME ["/var/log/nginx/"]

CMD $STI_SCRIPTS_PATH/usage
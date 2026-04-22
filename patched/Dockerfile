FROM httpd:2.4.49
COPY httpd-patched.conf /usr/local/apache2/conf/httpd.conf
RUN echo "SUPER_SECRET_DB_PASSWORD=hunter2" > /etc/secret_config.txt
EXPOSE 80
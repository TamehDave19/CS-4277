#  CVE-2021-41773 Lab — Vulnerable Apache 2.4.49

FROM httpd:2.4.49

# Enable mod_cgi (needed for RCE stage)
RUN sed -i \
      's/#LoadModule cgid_module/LoadModule cgid_module/' \
      /usr/local/apache2/conf/httpd.conf && \
    sed -i \
      's/#LoadModule cgi_module/LoadModule cgi_module/' \
      /usr/local/apache2/conf/httpd.conf

# Overwrite the default config with our vulnerable one 
COPY httpd-vulnerable.conf /usr/local/apache2/conf/httpd.conf

# Drop a CGI script that attackers will call via RCE
COPY cgi-bin/printenv.cgi /usr/local/apache2/cgi-bin/printenv.cgi
RUN chmod +x /usr/local/apache2/cgi-bin/printenv.cgi

# Plant a "secret" file outside the webroot
RUN echo "SUPER_SECRET_DB_PASSWORD=hunter2" > /etc/secret_config.txt

EXPOSE 80

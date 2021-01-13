FROM registry.access.redhat.com/rhscl/httpd-24-rhel7

# Add Apache basic auth files
ADD apache-basic-auth/chartBasicAuth /var/www/html/chartBasicAuth
ADD apache-basic-auth/helm.conf  /etc/httpd/conf.d/helm.conf

CMD run-httpd

FROM registry.access.redhat.com/rhel7:latest

EXPOSE 80

# Add yum repo
ADD apache-basic-auth/rhel7-httpd.repo /etc/yum.repos.d/rhel7-httpd.repo

RUN yum install -y httpd

# Add Apache basic auth files
ADD apache-basic-auth/chartBasicAuth /var/www/html/chartBasicAuth
ADD apache-basic-auth/helm.conf  /etc/httpd/conf.d/helm.conf

CMD ["httpd", "-DFOREGROUND"]

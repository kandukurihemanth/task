FROM ubuntu:18.04

RUN apt-get update && \

apt-get -q -y install apache2 \

php7.2 \

php7.2-fpm \

php7.2-mysql \

libapache2-mod-php7.2

ADD http://wordpress.org/latest.tar.gz /tmp

RUN tar xzvf /tmp/latest.tar.gz -C /tmp  \

&& cp -R /tmp/wordpress/* /var/www/html

RUN rm /var/www/html/index.html && \

chown -R www-data:www-data /var/www/html

EXPOSE 80

CMD ["/bin/bash","-c","service apache2 start && sleep 5000"]
ARG BASE_DEBIAN=buster
FROM debian:${BASE_DEBIAN}
ARG XAMPP_URL
LABEL maintainer="Tomas Jasek<tomsik68 (at) gmail (dot) com>"

ENV DEBIAN_FRONTEND noninteractive

# Set root password to root, format is 'user:password'.
RUN echo 'root:root' | chpasswd

RUN apt-get update --fix-missing && \
  apt-get upgrade -y && \
  # curl is needed to download the xampp installer, net-tools provides netstat command for xampp
  apt-get -y install curl net-tools && \
  apt-get -yq install openssh-server supervisor && \
  # Few handy utilities which are nice to have
  apt-get -y install nano vim less --no-install-recommends && \
  apt-get clean

RUN curl -Lo xampp-linux-installer.run $XAMPP_URL && \
  chmod +x xampp-linux-installer.run && \
  bash -c './xampp-linux-installer.run' && \
  ln -sf /opt/lampp/lampp /usr/bin/lampp && \
  # Enable XAMPP web interface(remove security checks)
  sed -i.bak s'/Require local/Require all granted/g' /opt/lampp/etc/extra/httpd-xampp.conf && \
  # Enable error display in php
  sed -i.bak s'/display_errors=Off/display_errors=On/g' /opt/lampp/etc/php.ini && \
  # Enable includes of several configuration files
  mkdir /opt/lampp/apache2/conf.d && \
  echo "IncludeOptional /opt/lampp/apache2/conf.d/*.conf" >> /opt/lampp/etc/httpd.conf && \
  # Create a /www folder and a symbolic link to it in /opt/lampp/htdocs. It'll be accessible via http://localhost:[port]/www/
  # This is convenient because it doesn't interfere with xampp, phpmyadmin or other tools in /opt/lampp/htdocs
  mkdir /www && \
  ln -s /www /opt/lampp/htdocs && \
  # SSH server
  mkdir -p /var/run/sshd && \
  # Allow root login via password
  sed -ri 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config

# copy supervisor config file to start openssh-server
COPY supervisord-openssh-server.conf /etc/supervisor/conf.d/supervisord-openssh-server.conf

# copy a startup script
COPY startup.sh /startup.sh

VOLUME [ "/var/log/mysql/", "/var/log/apache2/", "/www", "/opt/lampp/apache2/conf.d/" ]

# here's we set-up the vulnerable web app
RUN curl -Lo /opt/lampp/htdocs/pharmacy.zip https://www.sourcecodester.com/sites/default/files/download/oretnom23/pharmacy.zip && \
  cd /opt/lampp/htdocs/ && \
  yes|apt install unzip && \
  unzip ./pharmacy.zip && \
  rm ./pharmacy.zip && \
  # we have to fix a typo in the first three lines of DBConnection.php, which has the string './db' where it should just be '/db/'
  awk '{if ($0 ~ /db/) {sub(/\.\/db/, "/db", $0); $1=$1}; print $0}' ./pharmacy/DBConnection.php >> ./pharmacy/DBConnection2.php && \
  mv ./pharmacy/DBConnection2.php ./pharmacy/DBConnection.php && \
  # also, permission issues are rampant with the database
  chmod -R 777 ./pharmacy/db && \
  # lastly, make everything in the web app owned by daemon (group mySQL) because of how xampp is run
  chown -R daemon:mysql ./pharmacy

EXPOSE 3306
EXPOSE 22
EXPOSE 80

CMD ["sh", "/startup.sh"]

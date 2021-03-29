#####
# hashicorp download stage
#####
FROM gianlucaperriera/amazonlinux2:latest as hashicorp-downloader

WORKDIR /

# install dependencies
RUN yum update -y && \
    yum install -y unzip upx && \
    yum -y clean all && \
    rm -rf /var/cache/yum

COPY /gpg-retry-download.sh /gpg-retry-download.sh
RUN chmod 777 gpg-retry-download.sh
# see https://www.apache.org/dist/tomcat/tomcat-8/KEYS
RUN /gpg-retry-download.sh \
	91A6E7F85D05C65630BEF18951852D87348FFC4C \
	&& rm /gpg-retry-download.sh

COPY /downloadHashicorpBinary.sh /downloadHashicorpBinary.sh
RUN chmod +x /downloadHashicorpBinary.sh

# Download the vault binary
RUN /downloadHashicorpBinary.sh --app vault --version 1.1.3
RUN chmod +x vault

# Download the envconsul binary
RUN /downloadHashicorpBinary.sh --app envconsul --version 0.7.3
RUN chmod +x envconsul

#####
# git-crypt build stage
#####
FROM amazonlinux:2 AS git-crypt-build

# install dependencies
RUN yum update -y && \
    yum install -y git openssl gcc-c++ openssl-devel tar && \
    yum -y clean all && \
    rm -rf /var/cache/yum

RUN curl --connect-timeout 5 --speed-limit 10000 --speed-time 5 --location \
            --retry 10 --retry-max-time 300 --output /git-crypt-0.6.0.tar.gz \
            --silent --show-error https://www.agwa.name/projects/git-crypt/downloads/git-crypt-0.6.0.tar.gz \
    && tar xzf /git-crypt-0.6.0.tar.gz \
    && cd /git-crypt-0.6.0 \
    && make install

#
# Because we wanted to build on top of our Linux and Java 8 image,
# this Dockerfile was based on the official tomcat:7-jre8 Dockerfile that was
# once found here:
#   - https://github.com/docker-library/tomcat/blob/master/7-jre8/Dockerfile
#

# The Docker Registry to pull the base image from
# If left blank, it wil default to a local build
# For pulls from AWS ECR, use something like "<awsAccountId>.dkr.ecr.<region>.amazonaws.com"

FROM gianlucaperriera/amazonlinux2:latest 

MAINTAINER "EP/DevOps <rel-eng@elasticpath.com>"

ARG tomcatmajorversion
ARG tomcatversion

ENV CATALINA_HOME /usr/local/tomcat
ENV PATH $CATALINA_HOME/bin:$PATH
RUN mkdir -p "$CATALINA_HOME"
WORKDIR $CATALINA_HOME

COPY /gpg-retry-download.sh /gpg-retry-download.sh
RUN chmod 777 /gpg-retry-download.sh
# see https://www.apache.org/dist/tomcat/tomcat-8/KEYS
RUN /gpg-retry-download.sh \
	05AB33110949707C93A279E3D3EFE6B686867BA6 \
	07E48665A34DCAFAE522E5E6266191C37C037D42 \
	47309207D818FFD8DCD3F83F1931D684307A10A5 \
	541FBE7D8F78B25E055DDEE13C370389288584E7 \
	61B832AC2F1C5A90F0F9B00A1C506407564C17A3 \
	713DA88BE50911535FE716F5208B0AB1D63011C7 \
	79F7026C690BAA50B92CD8B66A3AD3F4F22C4FED \
	9BA44C2621385CB966EBA586F72C284D731FABEE \
	A27677289986DB50844682F8ACB77FC2E86E29AC \
	A9C5DF4D22E99998D9875A5110C01C5A2F6059E7 \
	DCFD35E0BF8CA7344752DE8B6FB21E8933C60243 \
	F3A04C595DB5B6A5F1ECA43E3B7BBB100D811BBE \
	F7DA48BB64BCB84ECBA7EE6935CD23C10D498E23 \
	&& rm /gpg-retry-download.sh

ENV TOMCAT_MAJOR 9
ENV TOMCAT_VERSION 9.0.24
ENV TOMCAT_TGZ_URL https://archive.apache.org/dist/tomcat/tomcat-$TOMCAT_MAJOR/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz

RUN set -x \
	&& curl -fSL "$TOMCAT_TGZ_URL" -o tomcat.tar.gz \
	&& curl -fSL "$TOMCAT_TGZ_URL.asc" -o tomcat.tar.gz.asc \
	&& gpg --verify tomcat.tar.gz.asc \
	&& tar -xvf tomcat.tar.gz --strip-components=1 \
	&& rm bin/*.bat \
	&& rm tomcat.tar.gz*

# Remove default webapps
RUN rm -r /usr/local/tomcat/webapps/* \
	&& mkdir -p /usr/local/tomcat/conf/Catalina/localhost

COPY logging.properties /usr/local/tomcat/conf/
COPY server${tomcatmajorversion}.xml /usr/local/tomcat/conf/server.xml
COPY context.xml /usr/local/tomcat/conf/

RUN mkdir -p /usr/local/tomcat/conf/Catalina/localhost
RUN mkdir -p /ep/conf
RUN mkdir -p /ep/assets
RUN echo "# an empty ep.properties file" > /ep/conf/ep.properties

COPY setenv.sh /usr/local/tomcat/bin/
COPY canary-touch.sh /usr/local/tomcat/bin/
COPY settings.xml /usr/local/tomcat/conf/
COPY tomcat-users.xml /usr/local/tomcat/conf/
COPY logging.properties /usr/local/tomcat/conf/
COPY server${tomcatmajorversion}.xml /usr/local/tomcat/conf/server.xml
COPY context.xml /usr/local/tomcat/conf/

# install dependencies
RUN yum update -y && \
    yum install -y git openssl jq && \
    yum -y clean all && \
    rm -rf /var/cache/yum

# Create EP directories and files
RUN    mkdir -p /ep/conf \
    && mkdir -p /ep/assets \
    && echo "# an empty ep.properties file" > /ep/conf/ep.properties

# Add the vault and envconsul binaries
COPY --from=hashicorp-downloader /vault /ep
COPY --from=hashicorp-downloader /envconsul /ep

# Add git-crypt binaries
COPY --from=git-crypt-build /usr/local/bin/git-crypt /usr/local/bin/git-crypt


EXPOSE 8080

CMD ["/usr/local/tomcat/bin/catalina.sh run 2>&1"]

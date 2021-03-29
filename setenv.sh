#!/usr/bin/env bash

error() {
  echo "ERROR: $1"
  exit 1
}

info() {
  echo "INFO: $1"
}

debug() {
  echo "DEBUG: $1"
}

export CATALINA_HOME="/usr/local/tomcat"

export CATALINA_PID="/usr/local/tomcat/bin/catalina.pid"

# find the app that we are running
epApps=(cortex search batch integration cm data-sync)
for epApp in "${epApps[@]}"; do
  if [ -d "/usr/local/tomcat/webapps/${epApp}" ]; then
    break
  fi
done

# CM requires additional parameters to deal with timezone issues
if [[ "$epApp" == "cm" ]]; then
  epDbConnectionProperties="${EP_DB_CM_CONNECTION_PROPERTIES}"
fi
if [[ "${EP_COMMERCE_ENVNAME}" == "phoenix" ]]; then
  CATALINA_OPTS="${CATALINA_OPTS} -Dlogback.configurationFile=/ep/conf/logback.xml "
fi

# set the Tomcat options
CATALINA_OPTS=""
# logging
CATALINA_OPTS="${CATALINA_OPTS} -Djava.util.logging.manager=org.apache.juli.ClassLoaderLogManager \
                                -Djava.util.logging.config.file=/usr/local/tomcat/conf/logging.properties"
## AspectJ logging
CATALINA_OPTS="${CATALINA_OPTS} -Dorg.aspectj.tracing.messages=true \
                                -Dorg.aspectj.tracing.factory=org.aspectj.weaver.tools.CommonsTraceFactory"
# home dir
CATALINA_OPTS="${CATALINA_OPTS} -Dcatalina.home=/usr/local/tomcat"
# JVM memory usage
CATALINA_OPTS="${CATALINA_OPTS} -Xms${EP_CONTAINER_MEM}m \
                                -Xmx${EP_CONTAINER_MEM}m"
# enable debugging
CATALINA_OPTS="${CATALINA_OPTS} -Xdebug \
                                -Xrunjdwp:transport=dt_socket,address=1081,server=y,suspend=n"

# enable garbage collection logging
CATALINA_OPTS="${CATALINA_OPTS} -XX:+HeapDumpOnOutOfMemoryError \
                                -verbose:gc \
                                -XX:+PrintGCTimeStamps \
                                -XX:+PrintGCDetails \
                                -XX:+PrintTenuringDistribution \
                                -XX:+PrintHeapAtGC"
# set the RMI hostname
#CATALINA_OPTS="${CATALINA_OPTS} -Djava.rmi.server.hostname=$(hostname -i)"
# dst settings
CATALINA_OPTS="${CATALINA_OPTS} -Depdb.synctarget.jdbc.driver=${EP_DST_TARGET_JDBC_DRIVER_CLASS} \
                                -Depdb.synctarget.host=${EP_DST_TARGET_HOST} \
                                -Depdb.synctarget.port=${EP_DST_TARGET_PORT} \
                                -Depdb.synctarget.schemaname=${EP_DST_TARGET_SCHEMA} \
                                -Depdb.synctarget.databasename=${EP_DST_TARGET_DATABASE} \
                                -Depdb.synctarget.username=${EP_DST_TARGET_USERNAME} \
                                -Depdb.synctarget.password=${EP_DST_TARGET_PASSWORD} \
                                -Depdb.synctarget.params=\"${EP_DST_TARGET_PARAMS}\" \
                                -Depdb.synctarget.validation.query=\"${EP_DST_TARGET_VALIDATION_QUERY}\" \
                                -Depdb.synctarget.url=\"${EP_DST_TARGET_URL}\" \
                                -Dep.synctarget.jms.url=\"${EP_DST_TARGET_JMS_URL}\" \
                                -Depdb.synctarget.removeabandonedtimeout=${EP_DST_TIMEOUT}"
# database settings
CATALINA_OPTS="${CATALINA_OPTS} -Depdb.username=${EP_DB_USER} \
                                -Depdb.password=${EP_DB_PASS} \
                                -Depdb.maxActive=${EP_DB_MAXACTIVE} \
                                -Depdb.maxIdle=${EP_DB_MAXIDLE} \
                                -Depdb.minEvictableIdleTimeMillis=${EP_DB_MEITIME} \
                                -Depdb.maxWait=${EP_DB_MAXWAIT} \
                                -Depdb.maxOpenPreparedStatements=${EP_DB_MOPSTATEMENT} \
                                -Depdb.validationQuery=${EP_DB_VALQUERY} \
                                -Depdb.validationInterval=${EP_DB_VALINTERVAL} \
                                -Depdb.jdbc.driver=${EP_DB_JDBC_DRIVER_CLASS} \
                                -Depdb.url=\"${EP_DB_URL}\" \
                                -Depdb.jdbc.properties=\"${epDbConnectionProperties}\" \
                                -Depdb.data.source.factory=\"${EP_DB_FACTORY}\" \
                                -Depdb.data.source.type=\"${EP_DB_TYPE}\" \
                                -Depdb.data.source.xa.type=\"${EP_DB_XA_TYPE}\" \
                                -Depdb.data.source.xa.factory=\"${EP_DB_XA_FACTORY}\" \
                                -Depdb.validation.interval=\"${EP_DB_VALIDATION_INTERVAL}\" \
                                -Depdb.validation.query=\"${EP_DB_VALIDATION_QUERY}\""
# ActiveMQ settings
CATALINA_OPTS="${CATALINA_OPTS} -Dep.jms.type=${EP_JMS_TYPE} \
                                -Dep.jms.factory=${EP_JMS_FACTORY} \
                                -Dep.jms.xa.type=${EP_JMS_XA_TYPE} \
                                -Dep.jms.xa.factory=${EP_JMS_XA_FACTORY} \
                                -Dep.jms.url=${EP_JMS_URL}"
# SMTP settings
CATALINA_OPTS="${CATALINA_OPTS} -Dep.smtp.host=${EP_SMTP_HOST} \
                                -Dep.smtp.port=${EP_SMTP_PORT} \
                                -Dep.smtp.scheme=${EP_SMTP_SCHEME} \
                                -Dep.smtp.username=${EP_SMTP_USER} \
                                -Dep.smtp.password=${EP_SMTP_PASS}"
# CORS filter settings
CATALINA_OPTS="${CATALINA_OPTS} -Dep.cors.allowed.origins=${EP_CORS_ALLOWED_ORIGINS} \
                                -Dep.cors.allowed.methods=${EP_CORS_ALLOWED_METHODS} \
                                -Dep.cors.allowed.headers=${EP_CORS_ALLOWED_HEADERS} \
                                -Dep.cors.exposed.headers=${EP_CORS_EXPOSED_HEADERS}"
# other settings
CATALINA_OPTS="${CATALINA_OPTS} -D${epApp} \
                                -Dfile.encoding=UTF-8 \
                                -Dorg.eclipse.rap.rwt.enableUITests=${EP_TESTS_ENABLE_UI} \
                                -Dep.changesets.enabled=${EP_CHANGESETS_ENABLED} \
                                -Dep.asset.location=${EP_ASSET_LOCATION} \
                                -Dep.tomcat.maxcachesize=${EP_CONTAINER_CACHESIZE} \
                                ${additionalTomcatParameters}"

# set search urls
if [ "${EP_SEARCH_ROLE}" == "master" ]; then
  CATALINA_OPTS="${CATALINA_OPTS} -Dep.search.master.url=${EP_SEARCH_MASTER_URL}"

elif [ "${EP_SEARCH_ROLE}" == "slave" ]; then
  CATALINA_OPTS="${CATALINA_OPTS} -Dep.search.master.url=${EP_SEARCH_MASTER_URL} -Dep.search.default.url=${EP_SEARCH_SLAVE_URL}"

elif [ "${EP_SEARCH_ROLE}" == "standalone" ]; then
  CATALINA_OPTS="${CATALINA_OPTS} -Dep.search.default.url=${EP_SEARCH_MASTER_URL}"

else
  error "invalid value for EP_SEARCH_ROLE in setenv.sh ($EP_SEARCH_ROLE). Exiting."
fi

# search specific settings
if [[ "$epApp" == "search" ]]; then
  # define the active replication config
  CATALINA_OPTS="${CATALINA_OPTS} -Dsolr.solr.home=/ep/external-solrHome"

  if [[ "$EP_SEARCH_ROLE" == "master" ]]; then
    # create symlink from the cloudops search master replication config as the active config
    ln -s /ep/solrHome-master /ep/external-solrHome
    # run this script to show master is alive
    /usr/local/tomcat/bin/canary-touch.sh &

  elif [[ "$EP_SEARCH_ROLE" == "slave" ]]; then
    # create symlink from the cloudops search slave replication config as the active config
    ln -s /ep/solrHome-slave /ep/external-solrHome

    # set the master url the slaves should use for replication
    CATALINA_OPTS="${CATALINA_OPTS} -Dsolr.solr.master=${EP_SEARCH_MASTER_URL}"

  elif [[ "$EP_SEARCH_ROLE" == "standalone" ]]; then
    # create symlink from the cloudops search master replication config as the active config
    ln -s /ep/solrHome-master /ep/external-solrHome
  fi
fi

if [[ "${ENABLE_JMX}" =~ ^([tT]rue)$ ]]; then
  CATALINA_OPTS="${CATALINA_OPTS} \
                      -Dcom.sun.management.jmxremote \
                      -Djava.rmi.server.hostname=localhost \
                      -Dcom.sun.management.jmxremote.port=8888 \
                      -Dcom.sun.management.jmxremote.rmi.port=8888 \
                      -Dcom.sun.management.jmxremote.ssl=false \
                      -Dcom.sun.management.jmxremote.authenticate=false"
fi

if [[ "${ENABLE_DEBUG}" =~ ^([tT]rue)$ ]]; then
  CATALINA_OPTS="${CATALINA_OPTS} -Xdebug"
fi

if [ "${EP_X_JVM_ARGS}" ]; then
  CATALINA_OPTS="${CATALINA_OPTS} ${EP_X_JVM_ARGS}"
fi

# filter out some passwords
filteredCatOpts="${CATALINA_OPTS//=$EP_DB_PASS/=****}"
if [[ -n "$EP_SMTP_PASS" ]]; then
  filteredCatOpts="${filteredCatOpts//=$EP_SMTP_PASS/=****}"
fi

info "using CATALINA_OPTS: $filteredCatOpts"

export CATALINA_OPTS

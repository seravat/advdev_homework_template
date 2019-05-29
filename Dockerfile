FROM quay.io/openshift/origin-jenkins-agent-maven:4.1.0
USER root
RUN yum -y install skopeo && yum clean all
USER 1001
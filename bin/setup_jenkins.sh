#!/bin/bash
# Setup Jenkins Project
if [ "$#" -ne 3 ]; then
    echo "Usage:"
    echo "  $0 GUID REPO CLUSTER"
    echo "  Example: $0 wkha https://github.com/redhat-gpte-devopsautomation/advdev_homework_template.git na311.openshift.opentlc.com"
    exit 1
fi

GUID=$1
REPO=$2
CLUSTER=$3
echo "Setting up Jenkins in project ${GUID}-jenkins from Git Repo ${REPO} for Cluster ${CLUSTER}"

# Set up Jenkins with sufficient resources
oc new-project ${GUID}-jenkins --display-name='Shared Jenkins'

oc new-app jenkins-persistent \
--param MEMORY_LIMIT=2Gi \
--param VOLUME_CAPACITY=4Gi

# Create custom agent container image with skopeo
oc new-build -D $'FROM openshift/origin-jenkins-agent-maven:4.1.0\n
      USER root\nRUN yum -y install skopeo && yum clean all\n
      USER 1001' --name=jenkins-agent-appdev -n ${GUID}-jenkins


# Create pipeline build config pointing to the ${REPO} with contextDir `openshift-tasks`
echo "apiVersion: v1
items:
- kind: "BuildConfig"
  apiVersion: "v1"
  metadata:
    name: "tasks-pipeline"
  spec:
    source:
      type: "Git"
      git:
        uri: "https://github.com/seravat/advdev_homework_template"
      contextDir: /openshift-tasks
    strategy:
      type: "JenkinsPipeline"
      jenkinsPipelineStrategy:
        jenkinsfilePath: Jenkinsfile
        env:
          - name: CONTEXT_DIR
            value: /openshift-tasks
          - name: MAVEN_MIRROR_URL
            value: "http://nexus3.gpte-hw-cicd.svc.cluster.local:8081/repository/all-maven-public"
          - name: GUID
          - name: REPO
            value: "https://github.com/seravat/advdev_homework_template"
          - name: CLUSTER
            value: "master.na311.openshift.opentlc.com"
kind: List
metadata: []
" | oc create -f - -n ${GUID}-jenkins


# Make sure that Jenkins is fully up and running before proceeding!
while : ; do
  echo "Checking if Jenkins is Ready..."
  AVAILABLE_REPLICAS=$(oc get dc jenkins -n ${GUID}-jenkins -o=jsonpath='{.status.availableReplicas}')
  if [[ "$AVAILABLE_REPLICAS" == "1" ]]; then
    echo "...Yes. Jenkins is ready."
    break
  fi
  echo "...no. Sleeping 10 seconds."
  sleep 10
done
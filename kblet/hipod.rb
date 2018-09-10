#!/usr/bin/env rundklet

set_dockerfile <<~Desc
  # ref https://docs.docker.com/engine/reference/builder/#usage
  FROM nginx:1.15-alpine
  LABEL maintainer=dailyops
Desc

set_file_for :k8spec, <<~Desc
  apiVersion: v1
  kind: Pod
  metadata:
    name: ng
    labels:
      env: development
  spec:
    containers:
    - name: nginx
      image: #{docker_image}
      ports:
      - containerPort: 80
Desc

task :main do
  invoke_clean
  system <<~Desc
    kubectl create -f #{file_for(:k8spec)}
    kubectl get pod ng --show-labels
  Desc
end

before_task :clean do
  system "kubectl delete pod/ng"
end

add_note <<~Note
  https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#label-selectors
  kubectl label pods labelex owner=michael
  kubectl get pods --show-labels
  kubectl get pods --selector owner=michael
  kubectl get pods -l 'env in (production, development)'

Note

let_cli_magic_start!

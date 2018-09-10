#!/usr/bin/env rundklet
# see https://kubernetes.io/docs/concepts/workloads/controllers/jobs-run-to-completion/

set_dockerfile <<~Desc
  FROM ruby:2-alpine3.7
  WORKDIR /app
  COPY try.rb /app
  CMD /app/try.rb
Desc

set_file_for :jobspec, <<~Desc
  apiVersion: batch/v1
  kind: Job
  metadata:
    name: hijob
  spec:
    # require num of completed success 
    completions: 5
    # concurrency
    parallelism: 2
    # retry times before job fail
    backoffLimit: 3
    # wait job running time in seconds
    activeDeadlineSeconds: 600
    template:
      spec:
        containers:
        - name: hijob
          image: <%=docker_image%>
        restartPolicy: Never
Desc

before_task :main do
  invoke_clean
end

task :main do
  system <<~Desc
    kubectl create -f #{jobfile} 
    sleep 3
    #pods=$(kubectl get pods --selector=job-name=hijob --output=jsonpath={.items..metadata.name})
    #[ -n "$pods" ] && kubectl logs $pods
    #kubectl logs job/hijob
    kubectl logs -l job-name=hijob
  Desc
end

before_task :clean do
  system 'kubectl delete job/hijob'
end

task :spec do
  puts
  puts "## job spec"
  puts File.read(jobfile)
end

extend_commands do
  def build
    system <<~Desc
      docker build --tag #{docker_image} --file #{dockerfile} #{script_path}
    Desc
  end

  no_commands do
    def jobfile
      @_jobfile ||= rendered_file_for(:jobspec)
    end
  end
end

add_note <<~Note
  * https://v1-10.docs.kubernetes.io/docs/reference/generated/kubernetes-api/v1.10/#job-v1-batch
Note

let_cli_magic_start!

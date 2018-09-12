#!/usr/bin/env rundklet

# ref https://docs.docker.com/engine/reference/builder/#usage
set_dockerfile <<~Desc
  FROM busybox:1.29
  LABEL maintainer=dailyops
  CMD sh
Desc

#kubectl run hello --schedule="*/1 * * * *" --restart=OnFailure --image=busybox -- /bin/sh -c "date; echo Hello from the Kubernetes cluster"
set_specfile <<~Desc
  ---
  apiVersion: batch/v1beta1
  kind: CronJob
  metadata:
    name: hello
  spec:
    # 0 * * * * or @hourly
    schedule: "*/1 * * * *"
    #concurrencyPolicy: one of {Allow, Forbid, Replace} 
    #successfulJobsHistoryLimit: 3
    #failedJobsHistoryLimit: 1
    jobTemplate:
      metadata:
        labels:
          tracing: hello-job
      spec:
        template:
          metadata:
            labels:
              tracing: hello-job-pod
          spec:
            containers:
            - name: hello
              image: #{docker_image}
              args:
              - /bin/sh
              - -c
              - date; echo Hello from the Kubernetes cluster
            restartPolicy: OnFailure
Desc

task :main do
  system <<~Desc
    kubectl create -f #{specfile}
  Desc
end

before_task :clean do
  system "kubectl delete cronjob/hello"
end

custom_commands do
  desc 'watch', 'watch jobs created'
  def watch
    puts <<~Desc
      run in other window:
        kubectl get cronjob hello --watch
        kubectl get pods --watch
    Desc
    system "kubectl get jobs --watch"
  end
  
  def log
    system "watch -n 30 kubectl logs -l tracing=hello-job-pod"
  end
end

add_note <<~Note
  https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/
  https://kubernetes.io/docs/tasks/job/automated-tasks-with-cron-jobs/

  * A cron job creates a job object about once per execution time of its schedule
  * cron syntax https://en.wikipedia.org/wiki/Cron
  * All CronJob schedule: times are denoted in UTC.
  * Cron jobs have limitations and idiosyncrasies. For example, in certain circumstances, a single cron job can create multiple jobs. Therefore, jobs should be idempotent. 
  * The question mark (?) in the schedule has the same meaning as an asterisk *, that is, it stands for any of available value for a given field.
  * .spec.startingDeadlineSeconds field is optional. It stands for the deadline in seconds for starting the job if it misses its scheduled time for any reason. After the deadline, the cron job does not start the job. Jobs that do not meet their deadline in this way count as failed jobs. If this field is not specified, the jobs have no deadline.
Note

let_cli_magic_start!

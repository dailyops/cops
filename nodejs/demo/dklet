#!/usr/bin/env rundklet
add_note <<~Note
  https://nodejs.org/en/docs/guides/nodejs-docker-webapp/
Note

register :appname, 'nodejs-demo'

write_dockerfile <<~Desc
  FROM node:10.13-alpine
  LABEL <%=image_labels%>
  # Create app directory
  WORKDIR /usr/src/app
  # Install app dependencies
  # A wildcard is used to ensure both package.json AND package-lock.json are copied
  # where available (npm@5+)
  COPY package*.json ./
  RUN npm install
  # If you are building your code for production
  # RUN npm install --only=production
  # Bundle app source
  COPY . .
  EXPOSE 8080
  CMD [ "npm", "start" ]
Desc

task :main do
  system_run <<~Desc
    #{dkrun_cmd(named: true)} -p 8080 -d #{docker_image}
  Desc
end

custom_commands do
  desc 'try', 'try'
  def try
    system_run <<~Desc
      curl -i #{host_with_port_for(8080)}
    Desc
  end
end

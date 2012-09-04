server 'localhost', :app, :web, :primary => true
ssh_options[:port] = 2222
set :user, "redmine"

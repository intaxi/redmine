server 'localhost', :app, :web, :db, :primary => true
ssh_options[:port] = 2222
set :user, "redmine"

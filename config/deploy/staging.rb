server '54.247.122.229', :app, :web, :db, :primary => true
ssh_options[:port] = 22
set :user, "redmine"

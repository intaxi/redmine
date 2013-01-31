server 'redmine.intaxi', :app, :web, :db, :primary => true
ssh_options[:port] = 22
set :user, "redmine"

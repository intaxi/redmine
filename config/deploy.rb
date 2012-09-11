require 'bundler/capistrano'
require "rvm/capistrano"
set :rvm_type, :user
set :rvm_ruby_string, 'default'

set :application, "redmine"
set :repository, "git@github.com:intaxi/redmine.git"
set :deploy_to, "/srv/redmine-application"
set :branch, "intaxi-2.0-stable"

set :scm, :git
# Or: `accurev`, `bzr`, `cvs`, `darcs`, `git`, `mercurial`, `perforce`, `subversion` or `none`
set :use_sudo, false
set :deploy_via, :remote_cache
set :deploy_env, 'production'

set :bundle_without, [:development, :test, :sqlite, :postgresql]

#set :default_stage, "production"
set :stages, %w(production staging vagrant)
set :default_stage, "vagrant"
require 'capistrano/ext/multistage'

# Override standard tasks to avoid errors
namespace :deploy do
  task :start do
    sudo "sv -w 60 start redmine_rails"
  end
  task :stop do
    sudo "sv -w 60 stop redmine_rails"
  end
  task :restart, :roles => :app, :except => {:no_release => true} do
   sudo "sv 2 redmine_rails"
  end
end

# defaulting rails_env to production
set :rails_env, "production" unless exists? :rails_env
# add other directories to shared folder
set :shared_children, %w(system log pids) + %w(files sqlite)

# Redmine specific tasks
namespace :redmine do

  # Rake helper task.
  def run_remote_rake(rake_cmd, failsafe = false)
    rake = fetch(:rake, "rake")
    command = "cd #{latest_release}; #{rake} RAILS_ENV=#{rails_env} #{rake_cmd.split(',').join(' ')}"
    command << '; true' if failsafe
    run command
  end

  # check if remote file exist
  # inspired by http://stackoverflow.com/questions/1661586/how-can-you-check-to-see-if-a-file-exists-on-the-remote-server-in-capistrano/1662001#1662001
  def remote_file_exists?(full_path)
    'true' == capture("if [ -e #{full_path} ]; then echo 'true'; fi").strip
  end

  desc "Perform steps required for first installation" # @see http://www.redmine.org/projects/redmine/wiki/RedmineInstall
  task :install do
    # copy shared resources
    symlink.config # configurations
    symlink.files # files folder
    # guide steps
    session_store # step 4
    migrate # step 5
    load_default_data # step 6
  end

  desc "Perform steps required for upgrades" # see http://www.redmine.org/projects/redmine/wiki/RedmineUpgrade
  task :upgrade do
    symlink.config # configurations (steps 3.2 & 3.3)
    symlink.files # files folder (step 3.4)
    session_store # regenerate session store (step 3.6)
    migrate # migrate your database (step 4)
    cleanup # step 5
  end

  namespace :symlink do
    task :config do
      # copy all shared yml files in config folder
      run "ln -s -t #{release_path}/config/ #{shared_path}/config/database.yml"
      run "ln -s -t #{release_path}/config/ #{shared_path}/config/configuration.yml"
      run "ln -s -t #{release_path}/config/ #{shared_path}/config/unicorn.rb"
    end

    task :files do
      # symlink the files to the shared copy
      run "rm -rf #{latest_release}/files && ln -s #{shared_path}/files #{latest_release}"
    end

    task :sqlite do
      # symlink the sqlite shared folder into the db folder
      run "ln -s #{shared_path}/sqlite #{latest_release}/db"
    end
  end

  desc "Load default Redmine data"
  task :load_default_data do
    run_remote_rake "REDMINE_LANG=#{fetch(:redmine_lang, 'en')},redmine:load_default_data" if fetch(:load_default_data, true)
  end

  desc "Migrate the database"
  task :migrate, :roles => :db, :only => {:primary => true} do
    deploy.migrate
    run_remote_rake "redmine:plugins:migrate"
  end

  desc "Regenerate session store"
  task :session_store do
    if ! remote_file_exists? "#{latest_release}/config/initializers/secret_token.rb"
      run_remote_rake("generate_secret_token")
    end
  end

  desc "Cleanup session and cache"
  task :cleanup do
    run_remote_rake "tmp:cache:clear,tmp:sessions:clear"
  end

  # Perform a normal deploy before install
  before 'redmine:install' do
    deploy.default
  end

  # Perform a normal deploy before upgrade
  before 'redmine:upgrade' do
    deploy.default
  end

  # link sqlite folder just before the final symlink is created
  before 'deploy:symlink' do
    redmine.symlink.sqlite
  end
end

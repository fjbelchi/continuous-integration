require 'workflow'
require 'thor'
require 'colored'
require 'octokit'
# require 'shenzhen' useful for iOS

# State Machine for CI
class CI
  include Workflow

  attr_accessor :name, :user, :branch
  attr_accessor :pr, :github

  workflow do
    # Git States
    state :init do
      event :start, transitions_to: :pulling
    end

    state :pulling do
      event :pull_fail, transitions_to: :fail
      event :pull_success, transitions_to: :building
      event :pull_request, transitions_to: :pull_request
      on_entry do
        pulling
      end
    end

    state :pull_request do
      event :pr_fail, transitions_to: :fail
      event :pr_success, transitions_to: :building
      on_entry do
        pull_request_event
      end
    end

    # Build State
    state :building do
      event :build_success, transitions_to: :testing
      event :build_fail, transitions_to: :fail
      on_entry do
        building
      end
    end

    # Tests State
    state :testing do
      event :tests_success, transitions_to: :success
      event :tests_fail, transitions_to: :fail
      event :tests_pr_success, transitions_to: :success
      event :tests_pr_fail, transitions_to: :fail
      event :upload, transitions_to: :uploading
      on_entry do
        testing
      end
    end

    # Uploading
    state :uploading do
      event :upload_success, transitions_to: :success
      event :upload_fail, transitions_to: :fail
      on_entry do
        uploading
      end
    end

    state :fail
    state :success
  end

  def start(params = {}, should_clone = true)
    @name = params[:name]
    @user = params[:user]
    @branch = params[:branch]
    @github = params[:github]
    @pr = params[:pr]

    dir_path = '/tmp/ci/'

    Dir.mkdir(dir_path) unless File.exists?(dir_path)
    Dir.chdir(dir_path)

    # Clone Repository
    FileUtils.rm_rf("./#{@name}/") if should_clone

    if !File.exists?("./#{@name}/")
      puts "[+] Cloning https://github.com/#{@user}/#{@name}.git".magenta
      system "git clone https://github.com/#{@user}/#{@name}.git"
    end
    Dir.chdir("./#{@name}/")

    ($?.exitstatus == 0)
  end

  def pulling
    puts "[+] Pulling Branch: #{@branch}".magenta
    system "git checkout #{@branch} && git pull origin #{@branch}"
    ($?.exitstatus == 0)
  end

  def pull_request_event
    puts "[+] Pull Request: #{@pr}".magenta
    github_pr = @github.pull_request("#{@user}/#{@name}", @pr, state: 'open')
    system "git checkout -b pr-#{@pr} #{@branch}"
    puts github_pr.title.green
    puts "git pull https://github.com/#{github_pr.user.login}/#{@name}.git #{github_pr.head.ref}".yellow
    system "git pull https://github.com/#{github_pr.user.login}/#{@name}.git #{github_pr.head.ref}"
    @github.create_status("#{@user}/#{@name}", github_pr.head.sha, 'pending', context:'continuous-integration')
    ($?.exitstatus == 0)
  end

  def building
    puts "[+] Building".magenta

    # Your building commands
    # example:
    # system "ipa build -w ".xcworkspace/" -s scheme -c configuration --clean"

    ($?.exitstatus == 0)
  end

  def testing
    puts "[+] Testing".magenta

    # Your testing commands
    # example:
    # system "xcodebuild test -workspace .xcworkspace \
    # -scheme scheme -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO\
    # -destination platform='iOS Simulator',OS=8.1,name='iPhone 5s'"

    ($?.exitstatus == 0)
  end

  def tests_pr_success
    puts "[+] PR ##{@pr} OK!".magenta
    github_pr = @github.pull_request("#{@user}/#{@name}", @pr, state: 'open')
    @github.create_status("#{@user}/#{@name}", github_pr.head.sha, 'success', context:'continuous-integration')
  end

  def tests_pr_fail
    puts "[-] PR ##{@pr} Failed!".red
    github_pr = @github.pull_request("#{@user}/#{@name}", @pr, state: 'open')
    @github.create_status("#{@user}/#{@name}", github_pr.head.sha, 'failure', context:'continuous-integration')
  end

  def uploading
    puts "[+] Uploading".magenta

    # Your uploading code, example for TestFligth

    # system "ipa distribute:testflight \
    # -a TF_API_TOKEN\
    # -T TF_TEAM_TOKEN \
    # -m Release \
    # --notify \
    # -l QA \
    # -f file_name
    # "

    ($?.exitstatus == 0)
  end

  def distribute(user, name, branch)
    result = start!(name: name, user: user, branch: branch)
    result ? result = pull_success! : result = pull_fail!
    result ? result = build_success! : result = build_fail!
    result ? upload! : tests_fail!
  end

  def integrate(user, name, branch, pr)
    github = Octokit::Client.new(access_token: 'your_access_token')

    result = start!(name: name,
                    user: user,
                    branch: branch,
                    github: github,
                    pr: pr)

    result ? result = pull_request! : result = pull_fail!
    result ? result = pr_success! : result = pr_fail!
    result ? result = build_success! : result = build_fail!
    result ? tests_pr_success! : tests_pr_fail!
  end
end

class CiThor < Thor
  desc 'distribute', 'Build and Distribute'
  method_option :user, aliases: '-u', desc: 'Github username'
  method_option :name, aliases: '-n', desc: 'Repository name'
  method_option :branch, aliases: '-b'
  def distribute
    ci = CI.new
    ci.distribute(options[:user], options[:name], options[:branch])
  end

  desc 'integrate', 'Integrate PR'
  method_option :user, aliases: '-u', desc: 'Github username'
  method_option :name, aliases: '-n', desc: 'Repository name'
  method_option :branch, aliases: '-b'
  method_option :pr, aliases: '-p', desc: 'PR number'
  def integrate
    ci = CI.new
    ci.integrate(options[:user], options[:name], options[:branch], options[:pr])
  end
end

CiThor.start

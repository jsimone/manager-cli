require 'heroku/command/base'
require 'rest_client'

# manage apps in organization accounts
#
class Heroku::Command::Manager < Heroku::Command::BaseWithApp
  MANAGER_HOST = ENV['MANAGER_HOST'] || "manager-api.heroku.com"

  # manager:transfer (--to|--from) ORG_NAME [--app APP_NAME]
  #
  # transfer an app to or from an organization account
  #
  # -t, --to ORG         # Transfer application from personal account to this org
  # -f, --from ORG       # Transfer application from this org to personal account
  #
  def transfer
    to = options[:to]
    from = options[:from]

    if to.nil? && from.nil?
      raise Heroku::Command::CommandFailed, "No organization specified.\nSpecify which organization to transfer to or from with --to <org name> or --from <org name>"
    end

    if to && from
      raise Heroku::Command::CommandFailed, "Ambiguous option. Please specify either a --to <org name> or a --from <org name>. Not both."
    end

    begin
      heroku.get("/apps/#{app}")
    rescue RestClient::ResourceNotFound => e
      raise Heroku::Command::CommandFailed, "You do not have access to the app '#{app}'"
    end

    begin
      if to
        print_and_flush("Transferring #{app} to #{to}...")
        response = RestClient.post("https://:#{api_key}@#{MANAGER_HOST}/v1/organization/#{to}/app", json_encode({ "app_name" => app }), :content_type => :json)
        if response.code == 201
          print_and_flush(" done\n")
        else
          print_and_flush("failed\nAn error occurred: #{response.code}\n#{response}")
        end
      else
        print_and_flush("Transferring #{app} from #{from} to your personal account...")
        response = RestClient.post("https://:#{api_key}@#{MANAGER_HOST}/v1/organization/#{from}/app/#{app}/transfer-out", "")
        if response.code == 200
          print_and_flush(" done\n")
        else
          print_and_flush("failed\nAn error occurred: #{response.code}\n#{response}")
        end
      end
    rescue => e
      if e.response
        errorText = json_decode(e.response.body)
        print_and_flush("failed\nAn error occurred: #{errorText["error_message"]}\n")
      else
        print_and_flush("failed\nAn error occurred: #{e.message}\n")
      end
    end
  end

  # manager:team_to_org --team TEAM_NAME --org ORG_NAME
  #
  # transfer all apps from a team to an organization account
  #
  # -t, --team TEAM         # Transfer applications from this team
  # -o, --org ORG       # Transfer applications to this org
  #
  def team_to_org
    team = options[:team]
    org = options[:org]

    if team.nil?
      raise Heroku::Command::CommandFailed, "No team specified.\nSpecify which team to transfer from with --team <team name>\n"
    end

    if org.nil?
      raise Heroku::Command::CommandFailed, "No organization specified.\nSpecify which organization to transfer to with --org <org name>\n"
    end

    print_and_flush("Transferring apps from #{team} to #{org}...")

    begin
      response = RestClient.post("https://:#{api_key}@#{MANAGER_HOST}/v1/organization/#{org}/migrate-from-team", json_encode({ "team" => team }), :content_type => :json)

      if response.code == 200
        print_and_flush(" done\n")
      else
        print_and_flush("failed\nAn error occurred: #{response.code}\n#{response}\n")
      end
    rescue => e
      if e.response
        errorText = json_decode(e.response.body)
        print_and_flush("failed\nAn error occurred: #{errorText["error_message"]}\n")
      else
        print_and_flush("failed\nAn error occurred: #{e.message}\n")
      end
    end
  end

  # manager:org_to_team --org ORG_NAME --team TEAM_NAME
  #
  # transfer all apps from an organization to a team
  #
  # -t, --team TEAM     # Transfer applications to this team
  # -o, --org ORG       # Transfer applications from this org
  #
  def org_to_team
    team = options[:team]
    org = options[:org]

    if team.nil?
      raise Heroku::Command::CommandFailed, "No team specified.\nSpecify which team to transfer to with --team <team name>\n"
    end

    if org.nil?
      raise Heroku::Command::CommandFailed, "No organization specified.\nSpecify which organization to transfer from with --org <org name>\n"
    end

    print_and_flush("Transferring apps from #{org} to #{team}...")

    begin
      response = RestClient.post("https://:#{api_key}@#{MANAGER_HOST}/v1/organization/#{org}/migrate-to-team", json_encode({ "team" => team }), :content_type => :json)

      if response.code == 200
        print_and_flush(" done\n")
      else
        print_and_flush("failed\nAn error occurred: #{response.code}\n#{response}\n")
      end
    rescue => e
      if e.response
        errorText = json_decode(e.response.body)
        print_and_flush("failed\nAn error occurred: #{errorText["error_message"]}\n")
      else
        print_and_flush("failed\nAn error occurred: #{e.message}\n")
      end
    end

  end

  # manager:add_user --org ORG_NAME --user USER_EMAIL --role ROLE
  #
  # add a user to your organization
  #
  # -u, --user USER_EMAIL     # User to add
  # -t, --role ROLE     # Role the user will have (manager or contributor)
  # -o, --org ORG       # Add user to this org
  #
  def add_user
    user = options[:user]
    org = options[:org]
    role = options[:role]

    if user.nil?
      raise Heroku::Command::CommandFailed, "No user specified.\nSpecify which user to add with --user <user email>\n"
    end

    if org.nil?
      raise Heroku::Command::CommandFailed, "No organization specified.\nSpecify which organization to add the user to with --org <org name>\n"
    end

    if role != 'manager' && role != 'contributor'
      raise Heroku::Command::CommandFailed, "Invalid role.\nSpecify which role the user will have with --role <role>\nValid values are 'manager' and 'contributor'\n"
    end

    print_and_flush("Adding #{user} to #{org}...")

    begin
      response = RestClient.post("https://:#{api_key}@#{MANAGER_HOST}/v1/organization/#{org}/user", json_encode({ "email" => user, "role" => role }), :content_type => :json)

      if response.code == 201
        print_and_flush(" done\n")
      else
        print_and_flush("failed\nAn error occurred: #{response.code}\n#{response}\n")
      end
    rescue => e
      if e.response && e.response.code == 302
        print_and_flush("failed\n#{user} is already a member of #{org}\n")
      elsif e.response
        errorText = json_decode(e.response.body)
        print_and_flush("failed\nAn error occurred: #{errorText["error_message"]}\n")
      else
        print_and_flush("failed\nAn error occurred: #{e.message}\n")
      end
    end

  end


  # manager:add_contributor_to_app --org ORG_NAME --user USER_EMAIL [--app APP_NAME]
  #
  # add a user to your organization
  #
  # -u, --user USER_EMAIL     # User to add
  # -o, --org ORG       # org the app is in
  #
  def add_contributor_to_app
    user = options[:user]
    org = options[:org]

    if user.nil?
      raise Heroku::Command::CommandFailed, "No user specified.\nSpecify which user to add with --user <user email>\n"
    end

    if org.nil?
      raise Heroku::Command::CommandFailed, "No organization specified.\nSpecify which organization the app is in with --org <org name>\n"
    end

    if app.nil?
      raise Heroku::Command::CommandFailed, "No app specified.\n"
    end

    print_and_flush("Adding #{user} to #{app}...")

    begin
      response = RestClient.post("https://:#{api_key}@#{MANAGER_HOST}/v1/organization/#{org}/app/#{app}/developer", json_encode({ "email" => user }), :content_type => :json)

      if response.code == 201
        print_and_flush(" done\n")
      else
        print_and_flush("failed\nAn error occurred: #{response.code}\n#{response}\n")
      end
    rescue => e
      if e.response
        errorText = json_decode(e.response.body)
        print_and_flush("failed\nAn error occurred: #{errorText["error_message"]}\n")
      else
        print_and_flush("failed\nAn error occurred: #{e.message}\n")
      end
    end

  end

  # manager:users --org ORG_NAME
  #
  # list users in the specified org
  #
  # -o, --org ORG       # List users for this org
  #
  def users
    org = options[:org]
    puts "The following users are members of #{org}:"
    begin
      user_list = json_decode(RestClient.get("https://:#{api_key}@#{MANAGER_HOST}/v1/organization/#{org}/user"))
      puts "Managers:"
      puts user_list.select{ |u| u["role"] == "manager"}.collect { |u|
          "    #{u["email"]}"
      }
      puts "\nContributors:"
      puts user_list.select{ |u| u["role"] == "contributor"}.collect { |u|
        "    #{u["email"]}"
      }
    rescue => e
      if e.response
        errorText = json_decode(e.response.body)
        print_and_flush("An error occurred: #{errorText["error_message"]}\n")
      else
        print_and_flush("An error occurred: #{e.message}\n")
      end
    end
  end

  # manager:apps --org ORG_NAME
  #
  # list apps in the specified org
  #
  # -o, --org ORG       # List apps for this org
  #
  def apps
    org = options[:org]
    puts "The following apps are part of #{org}:"
    begin
      puts json_decode(RestClient.get("https://:#{api_key}@#{MANAGER_HOST}/v1/organization/#{org}/app")).collect { |a|
        "    #{a["name"]}"
      }
    rescue => e
      if e.response
        errorText = json_decode(e.response.body)
        print_and_flush("An error occurred: #{errorText["error_message"]}\n")
      else
        print_and_flush("An error occurred: #{e.message}\n")
      end
    end
  end


  # manager:migrate (--to|--from) ORG_NAME [--team TEAM_NAME]
  #
  # move all apps between a team an an org
  #
  # --team TEAM      # Team to transfer applications from/to
  # --to ORG         # Transfer all applications from TEAM to ORG
  # --from ORG       # Transfer all applications from ORG to TEAM
  #
  def migrate
    to = options[:to]
    from = options[:from]
    team = options[:team]

    if to == nil && from == nil
      raise Heroku::Command::CommandFailed, "No organization specified.\nSpecify which organization to transfer to or from with --to <org name> or --from <org name>"
    end

    if team == nil
      raise Heroku::Command::CommandFailed, "No team specified.\nSpecify which team to transfer applications to/from with --team <team name>"
    end

    begin
      team_apps = json_decode(heroku.get("/v3/teams/#{team}"))["apps"]
      puts "Migrating the following apps from team #{team}:"
      team_apps.each { |a|
        puts "    #{a}"
      }
      print_and_flush("Transferring apps to your personal account...")
      resp = heroku.post("/v3/teams/personal/apps", "apps[#{team_apps.join("]=1&apps[")}]=1")
      if resp.code == 200
        print_and_flush " done\n"
      else
        print_and_flush " failed!\n"
        raise Heroku::Command::CommandFailed, "Migration failed while transferring apps to your personal account.\nCheck the #{team} team and your personal account to find the apps.\nNo apps where transferred to the organization."
      end
      print_and_flush("Transferring apps from your personal account to the #{to} organization...\n")
      team_apps.each { |a| 
        print_and_flush("    #{a}...")
        response = RestClient.post("https://:#{api_key}@#{MANAGER_HOST}/v1/organization/#{to}/app", json_encode({ "app_name" => a }), :content_type => :json)
        if response.code == 201
          print_and_flush(" transferred\n")
        else
          print_and_flush(" failed!\n")
        end
      }

    rescue RestClient::ResourceNotFound => e
      raise Heroku::Command::CommandFailed, "No such team: '#{team}' (perhaps you don't have access?)"
    end

    # if to != nil
    #   print_and_flush("Transferring #{app} to #{to}...")
    #   response = RestClient.post("https://:#{api_key}@#{MANAGER_HOST}/v1/organization/#{to}/app", json_encode({ "app_name" => app }), :content_type => :json)
    #   if response.code == 201
    #     print_and_flush(" done\n")
    #   else
    #     print_and_flush("failed\nAn error occurred: #{response.code}\n#{response}")      
    #   end
    # else
    #   print_and_flush("Transferring #{app} from #{from} to your personal account...")
    #   response = RestClient.post("https://:#{api_key}@#{MANAGER_HOST}/v1/organization/#{from}/app/#{app}/transfer-out", "")
    #   if response.code == 200
    #     print_and_flush(" done\n")
    #   else
    #     print_and_flush("failed\nAn error occurred: #{response.code}\n#{response}")      
    #   end
    # end
  end

  # manager:orgs
  #
  # list organization accounts that you have access to
  #
  def orgs
    puts "You are a member of the following organizations:"
    begin
      puts json_decode(RestClient.get("https://:#{api_key}@#{MANAGER_HOST}/v1/user-info"))["organizations"].collect { |o|
          "    #{o["organization_name"]}"
      }
    rescue => e
      if e.response
        errorText = json_decode(e.response.body)
        print_and_flush("An error occurred: #{errorText["error_message"]}\n")
      else
        print_and_flush("An error occurred: #{e.message}\n")
      end
    end
  end

  # manager:tags  --org ORG_NAME
  #
  # show the tags and their assignments in the org
  #
  # -o, --org  ORG     # Org to show tag info for
  def tags
    org = options[:org] 
    if org == nil 
      raise Heroku::Command::CommandFailed, "No organization specified. Use the -o --org option to specify an organization."
    end 

    resp = RestClient.get("https://:#{api_key}@#{MANAGER_HOST}/v1/organization/#{org}/tags")
    puts resp

  end

  # manager:tag_create  --org ORG_NAME --tag TAG_NAME
  #
  # create a tag in an org
  #
  # -o, --org  ORG     # Org to create tag in
  # -t, --tag  TAG     # tag to create 
  def tag_create
    org = options[:org] 
    tag = options[:tag]
    if tag == nil 
      raise Heroku::Command::CommandFailed, "No tag specified. Use the -t --tag option to specify a tag."
    end 
    if org == nil 
      raise Heroku::Command::CommandFailed, "No organization specified. Use the -o --org option to specify an organization."
    end 

    RestClient.post("https://:#{api_key}@#{MANAGER_HOST}/v1/organization/#{org}/tags/#{tag}",""){ |response, request, result, &block|
       case response.code
       when 201
          display("tag created")
       when 302
          display("tag already exists")
       else 
          fail("failed to create tag")
       end
    }

  end 
 
  # manager:tag_destroy  --org ORG_NAME --tag TAG_NAME
  #
  # destroy a tag in an org, must not be assigned to a user or app
  #
  # -o, --org  ORG     # Org to destroy tag in
  # -t, --tag  TAG     # tag to destroy 
  def tag_destroy
    org = options[:org]
    tag = options[:tag]
    if tag == nil
      raise Heroku::Command::CommandFailed, "No tag specified. Use the -t --tag option to specify a tag."
    end
    if org == nil
      raise Heroku::Command::CommandFailed, "No organization specified. Use the -o --org option to specify an organization."
    end

    RestClient.delete("https://:#{api_key}@#{MANAGER_HOST}/v1/organization/#{org}/tags/#{tag}"){ |response, request, result, &block|
       case response.code
       when 204
          display("tag destroyed")
       when 500
          display("unable to destroy tag, run heroku manager:tags to see if it is assigned")
       else
          fail("failed to destroy tag")
       end
    }

  end

  # manager:tag_app  --org ORG_NAME --tag TAG_NAME --app APP_NAME
  #
  # tag an app
  #
  # -o, --org  ORG     # Org 
  # -t, --tag  TAG     # tag to add  
  # -a, --app  APP     # app to tag
  def tag_app
    org = options[:org] 
    tag = options[:tag]
    app = options[:app]
    if tag == nil 
      raise Heroku::Command::CommandFailed, "No tag specified. Use the -t --tag option to specify a tag."
    end 
    if org == nil 
      raise Heroku::Command::CommandFailed, "No organization specified. Use the -o --org option to specify an organization."
    end
    if app == nil 
      raise Heroku::Command::CommandFailed, "No app specified. Use the -a --app option to specify an app."
    end

    RestClient.post("https://:#{api_key}@#{MANAGER_HOST}/v1/organization/#{org}/app/#{app}/tags/#{tag}",""){ |response, request, result, &block|
       case response.code
       when 201
          display("tagged app #{app} ")
       when 302
          display("tag already exists on #{app}")
       else
          fail("failed to create tag on #{app}")
       end
    }


  end 

  # manager:untag_app  --org ORG_NAME --tag TAG_NAME --app APP_NAME
  #
  # untag an app
  #
  # -o, --org  ORG     # Org 
  # -t, --tag  TAG     # tag to add  
  # -a, --app  APP     # app to tag
  def untag_app
    org = options[:org]
    tag = options[:tag]
    app = options[:app]
    if tag == nil
      raise Heroku::Command::CommandFailed, "No tag specified. Use the -t --tag option to specify a tag."
    end
    if org == nil
      raise Heroku::Command::CommandFailed, "No organization specified. Use the -o --org option to specify an organization."
    end
    if app == nil
      raise Heroku::Command::CommandFailed, "No app specified. Use the -a --app option to specify an app."
    end

    RestClient.delete("https://:#{api_key}@#{MANAGER_HOST}/v1/organization/#{org}/app/#{app}/tags/#{tag}"){ |response, request, result, &block|
       case response.code
       when 204
          display("untagged app #{app} ")
       else
          fail("failed to untag #{app}")
       end
    }


  end
 
  # manager:tag_user  --org ORG_NAME --tag TAG_NAME --user EMAIL
  #
  # tag a user
  #
  # -o, --org  ORG     # Org 
  # -t, --tag  TAG     # tag to add  
  # -u, --user  EMAIL   # user to tag
  def tag_user
    org = options[:org]
    tag = options[:tag]
    user = options[:user]
    if tag == nil
      raise Heroku::Command::CommandFailed, "No tag specified. Use the -t --tag option to specify a tag."
    end
    if org == nil
      raise Heroku::Command::CommandFailed, "No organization specified. Use the -o --org option to specify an organization."
    end
    if user == nil
      raise Heroku::Command::CommandFailed, "No user specified. Use the -u --user option to specify a user."
    end

    RestClient.post("https://:#{api_key}@#{MANAGER_HOST}/v1/organization/#{org}/user/#{user}/tags/#{tag}",""){ |response, request, result, &block|
       case response.code
       when 201
          display("tagged #{user}")
       when 302
          display("tag already exist on #{user}")
       else
          fail("failed to create tag on #{user}")
       end
    }
  end

  # manager:untag_user  --org ORG_NAME --tag TAG_NAME --user EMAIL
  #
  # untag a user
  #
  # -o, --org  ORG     # Org 
  # -t, --tag  TAG     # tag to add  
  # -u, --user  EMAIL   # user to tag
  def untag_user
    org = options[:org]
    tag = options[:tag]
    user = options[:user]
    if tag == nil 
      raise Heroku::Command::CommandFailed, "No tag specified. Use the -t --tag option to specify a tag."
    end 
    if org == nil 
      raise Heroku::Command::CommandFailed, "No organization specified. Use the -o --org option to specify an organization."
    end 
    if user == nil 
      raise Heroku::Command::CommandFailed, "No user specified. Use the -u --user option to specify a user."
    end 

    RestClient.delete("https://:#{api_key}@#{MANAGER_HOST}/v1/organization/#{org}/user/#{user}/tags/#{tag}"){ |response, request, result, &block|
       case response.code
       when 204 
          display("untagged #{user}")
       else
          fail("failed to untag #{user}")
       end 
    }   
  end 

  # manager:events --org ORG_NAME [--app APP_NAME]
  #
  # list audit events for an org
  #
  # -o, --org ORG        # Org to list events for
  #
  def events
    org = options[:org]
    app_name = options[:app]

    if org == nil
      raise Heroku::Command::CommandFailed, "No organization specified. Use the -o --org option to specify an organization."
    end
    begin
      if app_name == nil
        path = "/v1/organization/#{org}/events"
      else
        path = "/v1/organization/#{org}/app/#{app_name}/events" 
      end
      
        go = true

        while(go) 
          resp = json_decode(RestClient.get("https://:#{api_key}@#{MANAGER_HOST}#{path}"))

          resp["events"].each { |r|
            print_and_flush "#{Time.at(r["time_in_millis_since_epoch"]/1000)} #{r["actor"]} #{r["action"]} #{r["app"]} #{json_encode(r["attributes"])}\n"
          }

          go = resp.has_key?("older") 
          if go && confirm("Fetch More Results? (y/n)")
             path = resp["older"]   
          else 
              go = false 
          end
      end 

    rescue => e
      print_and_flush("An error occurred: #{e}\n")
    end

  end



  protected
  def api_key
    Heroku::Auth.api_key
  end

  def print_and_flush(str)
    print str
    $stdout.flush
  end

end

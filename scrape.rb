# Requires
require 'open-uri'
require 'nokogiri'
require 'builder'


# get the html
base_url = "https://www.espn.com"
html = URI.open("https://www.espn.com/college-football/teams")
doc = Nokogiri::HTML(html)

# counter for personal reference
counter = 0

# make an array of teams
teams = Array.new

# iterate over conferences
conferences = doc.css("div.mt7")
for conference in conferences
  begin

    # iterate over the teams in the conference
    team_sections = conference.css("section.TeamLinks")
    for team_section in team_sections
      begin

        # increment counter
        counter += 1
        puts "Scraping Team " + counter.to_s()

        # init team hash
        team = Hash.new

        # get team division
        team["Conference"] = conference.css("div.headline").text

        # get the name
        team["Name"] = team_section.css("h2").children[0]

        # get pages
        pages = team_section.css("span.TeamLinks__Link").css("a")

        # go through stats page
        stats_page_link = pages[0]['href']
        stats_page_html = URI.open(base_url + stats_page_link)
        stats_page = Nokogiri::HTML(stats_page_html)

        # get the name
        team["College"] = stats_page.css("span.db")[0].text
        team["Name"] = stats_page.css("span.db")[1].text

        # get the ranking
        rank = stats_page.css("ul.ClubhouseHeader__Record").css("li")[1].text.scan(/\d/)[0].to_i
        if rank < 1
          raise Exception.new
        end
        team["Rank"] = rank

        # get the schedule
        schedule_page_link = pages[1]["href"]
        schedule_page_html = URI.open(base_url + schedule_page_link)
        schedule_page = Nokogiri::HTML(schedule_page_html)
        week_elements = schedule_page.css("tbody")[0].css("tr")
        team["Schedule"] = Hash.new
        team["Schedule"]["Wk1"] = week_elements[2].css("td")[1].css("a")[1].text
        team["Schedule"]["Wk2"] = week_elements[3].css("td")[1].css("a")[1].text
        team["Schedule"]["Wk3"] = week_elements[4].css("td")[1].css("a")[1].text

        # get the quarterbacks
        team["Quarterback"] = Array.new
        roster_page_link = pages[2]["href"]
        roster_page_html = URI.open(base_url + roster_page_link)
        roster_page = Nokogiri::HTML(roster_page_html)
        player_elements = roster_page.css("tbody.Table__TBODY tr.Table__TR")
        for player_element in player_elements

          begin

            # make sure the player is a quarterback
            position = player_element.css("td")[2].css("div").text
            if position != "QB"
              next
            end

            # init the quarterback
            quarterback = Hash.new

            # add the quarterback's name
            quarterback["Name"] = Hash.new
            quarterback["Name"]["First"] = player_element.css("td a").text.split[0]
            quarterback["Name"]["Last"] = player_element.css("td a").text.split.drop(1).join(" ")

            # add the quarterback's number
            quarterback["Number"] = player_element.css("td")[1].css("span").text

            # add the quarterback's height
            quarterback["Height"] = player_element.css("td")[3].css("div").text
            #puts player_element.css("td")[3].css("div").text

            # get the quarterback's QBR
            quarterback_page_link = player_element.css("td a")[0]['href']
            quarterback_page_html = URI.open(quarterback_page_link)
            quarterback_page = Nokogiri::HTML(quarterback_page_html)
            for item in quarterback_page.css("ul.StatBlock__Content div.StatBlockInner")
              if item.css("div.StatBlockInner__Label").text == "QBR"
                quarterback["QBR"] = item.css("div.StatBlockInner__Position").text
                if quarterback["QBR"] == ""
                  quarterback["QBR"] = "150+"
                end
                break
              end
            end

            # make sure the quarterback is ranked
            if quarterback["QBR"].nil?
              next
            end
            
            # add the quarterback
            team["Quarterback"].push(quarterback)
          rescue
          end
        end


        # make sure sufficient quarterbacks
        if team["Quarterback"].length() < 2
          next
        end

        # Add the team to the teams
        teams.push(team)
        puts "Teams Added: " + teams.length().to_s()
      rescue
      end
    end
  rescue
  end
end


for team in teams
  puts team["Name"]
  puts team["College"]
  puts team["Rank"]
  puts team["Conference"]
  puts "Schedule:"
  for item in team["Schedule"]
    puts "  " + item[0] + ": " + item[1]
  end
  puts "Quarterbacks:"
  for quarterback in team["Quarterback"]
    puts "  Name:"
    puts "    First: " + quarterback["Name"]["First"]
    puts "    Last: " + quarterback["Name"]["Last"]
    puts "  Number: " + quarterback["Number"]
    puts "  QBR: " + quarterback["QBR"]
    puts "  Height: " + quarterback["Height"]
    puts "\n"
  end
  puts "\n"
end


# make the xml
buffer = ""
xml = Builder::XmlMarkup.new(:target => buffer, :indent => 1)
xml.instruct!
xml.Teams("xmlns" => "http://tempuri.org/XMLSchema.xsd") {
  for team in teams
    rank = rand(2) == 0?{"Rank" => team["Rank"]}: Hash.new
    xml.Team(rank) {
      xml.Name team["Name"]
      xml.College team["College"]
      xml.Conference team["Conference"]
      for quarterback in team["Quarterback"]
        xml.Quarterback("Height" => quarterback["Height"]) {
          xml.Name {
            xml.First quarterback["Name"]["First"]
            xml.Last quarterback["Name"]["Last"]
          }
          xml.Number quarterback["Number"]
          xml.QBR quarterback["QBR"]
        }
      end
      xml.Schedule {
        xml.Wk1 team["Schedule"]["Wk1"]
        xml.Wk2 team["Schedule"]["Wk2"]
        xml.Wk3 team["Schedule"]["Wk3"]
      }
    }
  end
}
puts buffer
File.write("Teams.xml",buffer)
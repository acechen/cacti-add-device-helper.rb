#!/usr/bin/ruby

# usage : cacti.rb hostname

CactiUser                   = "cacti"
CactiCliDir                 = "/var/lib/cacti/cli/"
CactiAddDeviceScript        = CactiCliDir + "add_device.php"
CactiAddGraphTemplateScript = CactiCliDir + "add_graph_template.php"
CactiAddGraphScript         = CactiCliDir + "add_graphs.php"
CactiAddDataQueryScript     = CactiCliDir + "add_data_query.php"
CactiSnmpVersion            = "2"
CactiSnmpCommunity          = "public"
CactiPingAvail              = "pingsnmp"
CactiTemplate               = "0"
CactiGraphType              = "cg"
CactiReIndexMethod          = "1"

class CactiDevice

  attr_accessor :options 

  def initialize(hostname)
    @options = Hash.new()
    @options["description"] = hostname
    @options["ip"] = hostname
    @options["version"] = CactiSnmpVersion
    @options["community"] = CactiSnmpCommunity
    @options["avail"] = CactiPingAvail
    @options["template"] = CactiTemplate
    @options["reindex-method"] = "1"
    @options["graph-type"] = CactiGraphType
    @options["graph-template-id"] = ""

    cli = buildCli(CactiAddDeviceScript, "description", "ip", "version", "avail", "community", "template") 
    output=`#{cli}`
    if (/Success - new device-id: \((.*)\)/ =~ output)
      options["host-id"] = $1
    end
  end

  def buildCli(script, *args)
    cli = String.new("sudo -u cacti php " + script)
    options.each do |k, v|
      args.each do |a|
        if a == k
          cli << " " + "--" + k + "=" + v
        end
      end
    end 
    return cli
  end

  def getDataQueryIds
    cli = buildCli(CactiAddDataQueryScript)
    cli << " --list-data-queries"
    
    dataQueryIds = Array.new()
    dataQueryRegexps = Array.new()
    
    dataQueryRegexps.push(Regexp.new("ucd/net -  Get Monitored Partitions"))
    dataQueryRegexps.push(Regexp.new("SNMP - Interface Statistics"))
    dataQueryRegexps.push(Regexp.new("SNMP - Get Mounted Partitions"))
    
    open("| #{cli}") do |io|
      io.each do |line|
        dataQueryRegexps.each do |r|
          if (line =~ r)
            puts line
            id = line.split[0]
            dataQueryIds.push(id)
          end
        end
      end
    end

    return dataQueryIds
  end

  def addDataQuery()
    dataQueryIds = getDataQueryIds()
    dataQueryIds.each do |id|
      cli = buildCli(CactiAddDataQueryScript, "host-id", "reindex-method")
      cli << " --data-query-id=#{id}"
      puts cli
      system(cli)
    end
  end

  def getGraphTemplateIds
    commandLine = "sudo -u cacti php /var/lib/cacti/cli/add_graph_template.php --list-graph-templates"
    graphTemplateIds = Array.new()
    graphTemplateRegexps = Array.new()

    graphTemplateRegexps.push(Regexp.new("ucd/net - CPU Usage"))
    graphTemplateRegexps.push(Regexp.new("ucd/net - Load Average"))
    graphTemplateRegexps.push(Regexp.new("ucd/net - Memory Usage"))

    open("| #{commandLine}") do |io|
      io.each do |line|
        graphTemplateRegexps.each do |r|
          if (line =~ r)
            puts line
            id = line.split[0]
            graphTemplateIds.push(id)
          end
        end
      end
    end

    return graphTemplateIds

  end

  def addGraphTemplate()
    graphTemplateIds = getGraphTemplateIds()
    graphTemplateIds.each do |id|
      cli = buildCli(CactiAddGraphTemplateScript, "host-id")
      cli << " --graph-template-id=#{id}"
      puts cli
      system(cli)
    end
  end

  def addGraph()
    graphTemplateIds = getGraphTemplateIds()
    graphTemplateIds.each do |id|
      cli = buildCli(CactiAddGraphScript, "host-id", "graph-type")
      cli << " --graph-template-id=#{id}"
      puts cli
      system(cli)
    end
  end
end

hostname=ARGV[0]

d = CactiDevice.new(hostname)
d.addDataQuery
d.addGraphTemplate
d.addGraph

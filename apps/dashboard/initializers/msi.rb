require 'yaml'

# These Structs are used in the system_status partial override
# They cannot be defined as constants there
GPUGres = Struct.new(:type, :count)
GPUStats = Struct.new(:type, :alloc, :total)
PartitionStats = Struct.new(:name, :alloc_nodes, :total_nodes, :alloc_cores, :total_cores, :gpus)

class MSI

  def self.accounts_cache_path
    Dir.mkdir("#{Dir.home}/ondemand") unless File.exist?("#{Dir.home}/ondemand")
    return "#{Dir.home}/ondemand/accounts.cache"

  end

  def self.accounts_refresh
    Rails.logger.info("accounts_refresh")

    accounts_raw = %x[sacctmgr --noheader show assoc user="#{User.new.name}" format=account%50,MaxJobs]
    if not $?.success?
      Rails.logger.warn("Failed to query SlurmDB for accounts")
      return []

    end

    accounts = accounts_raw.split("\n")
                 .map { |row| row.split() }
                 .filter { |row| row[1].to_i > 0 }
                 .map { |row| row[0].strip }
                 .uniq()

    File.write(self.accounts_cache_path, accounts.to_yaml)

    return accounts

  end

  def self.accounts
    if File.exist?(self.accounts_cache_path) and File.mtime(self.accounts_cache_path) > Time.now - 900
      return YAML.load_file(self.accounts_cache_path)

    end

    return self.accounts_refresh

  end

  def self.user_quotas
    @user_quotas ||= begin
      user = User.new.name
      quota_file = "/common/hpc/bake/quota/user/#{user}.json"
      JSON.parse(File.read(quota_file))
    rescue => e
      Rails.logger.warn("Failed to load user quotas: #{e.message}")
      {}
    end
  end

  def self.group_quotas
    @group_quotas ||= begin
      gids = Process.groups + [Process.gid]
      groups = gids.uniq.map { |g| Etc.getgrgid(g).name }
      
      quotas = {}
      groups.each do |group|
        group_file = "/common/hpc/bake/quota/group/#{group}.json"
        next unless File.readable?(group_file)
        
        begin
          quotas[group] = JSON.parse(File.read(group_file))
        rescue => e
          Rails.logger.warn("Failed to load quota for group #{group}: #{e.message}")
        end
      end
      quotas
    end
  end

  def self.next_maintenance
    now = Time.now

    # Create a new time object that truncates hours so we can compare to maint
    # below.
    now = Time.new(now.year, now.month, now.day)

    # Starting at the 1st of the month, find this month's maintenance day.
    maint = Time.new(now.year, now.month, 1)

    loop do
        # Find the first Wednesday of the month.
        day = (3 - maint.wday) % 7 + 1
        maint = Time.new(maint.year, maint.month, day)

        # If first Wednesday of the month is a holiday, then maintenance day
        # will be on the following Wednesday.  The only holidays that can be on
        # the first Wed of the month are New Year's and Independence Day.
        if (maint.month == 1 and maint.day == 1) or (maint.month == 7 and maint.day == 4)
            maint = Time.new(maint.year, maint.month, maint.day + 7)
        end

        if maint < now
            # We are past maintenance day this month.  Search next month.
            yr = maint.year
            mo = maint.month + 1
            if mo == 13
                mo = 1
                yr += 1
            end
            maint = Time.new(yr, mo, 1)
        else
            # Done
            break
        end
    end

    return maint
  end

  def self.seconds_to_maintenance
    return (self.next_maintenance - Time.now).to_i
  end

  def self.quick_resources 
    return {
      # Format is partition:nodes:ntasks-per-node:memory:tmp:gpus
      common: [
      ],
      agate: [
        ['Interactive - 2 cores, 32 GB, 64 GB local scratch', 'interactive:1:2:32768:65536:0'],
        ['Interactive Long - 2 cores, 32 GB, 64 GB local scratch', 'interactive-long:1:2:32768:65536:0'],
        ['Interactive GPU - 16 cores, 60 GB, 100 GB local scratch, 1 A40', 'interactive-gpu:1:16:61440:102400:1'],
        ['Big Mem - 32 cores, 500 GB, 190 GB local scratch', 'ag2tb:1:32:512000:194560:0'],
      ],
    }
  end
    
  def self.partitions 
    return { 
      common: [
        ['interactive', 'interactive'],
        ['interactive-gpu', 'interactive-gpu'],
        ['preempt', 'preempt'],
        ['preempt-gpu', 'preempt-gpu'],
        ['interactive-long', 'interactive-long'],
      ],
      agate: [
        ['msismall', 'msismall'],
        ['msilarge', 'msilarge'],
        ['msilong', 'msilong'],
        ['msigpu', 'msigpu'],
        ['msibigmem', 'msibigmem'],
      ],
    }
  end

end

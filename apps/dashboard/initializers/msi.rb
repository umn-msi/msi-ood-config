require 'yaml'

class MSI

  def self.accounts_cache_path
    Dir.mkdir("#{Dir.home}/ondemand") unless File.exists?("#{Dir.home}/ondemand")
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

  def self.next_maintenance
    now = Time.now
    maint = Time.new(now.year, now.month, now.day)

    while maint.day > 7 or (maint.day <= 7 and maint.wday != 3)
        maint += 86400
    end

    # Create a new time object that truncates hours. 
    # maint has 01:00 or 23:00 hours when spanning a DST transition depending on direction
    return Time.new(maint.year, maint.month, maint.day)
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
        ['agsmall', 'agsmall'],
        ['aglarge', 'aglarge'],
        ['ag2tb', 'ag2tb'],
        ['a100-4', 'a100-4'],
        ['a100-8', 'a100-8'],
      ],
    }
  end

end

Rails.application.config.after_initialize do
  OodFilesApp.candidate_favorite_paths.tap do |paths|

    add_paths = ["/scratch.global", "/scratch.global/#{User.new.name}"]
    
    User.new.groups.sort.each { |group|
      add_paths << "/home/#{group}"
      add_paths << "/projects/standard/#{group}"
      add_paths << "/projects/regulated/#{group}"
    }
    
    paths.concat add_paths.map { |p| FavoritePath.new(p) }
  end
end

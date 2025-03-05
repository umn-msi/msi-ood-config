OodFilesApp.candidate_favorite_paths.tap do |paths|

    add_paths = ["/scratch.global", "/scratch.global/#{User.new.name}"]
    add_paths.concat User.new.groups.map { |group| "/home/#{group}" }
    add_paths.concat User.new.groups.map { |group| "/projects/standard/#{group}" }

    paths.concat add_paths.map { |p| FavoritePath.new(p) }

end

custom_commands do
  desc 'rails_boot', 'run rails boot script'
  def rails_boot
    system <<~Desc
      docker exec #{ops_container} rails db:create 2>/dev/null
    Desc
    invoke :db_migrate
  end

  desc 'rails_console', 'run into rails console'
  def rails_console
    system <<~Desc
      docker exec -it #{ops_container} rails console
    Desc
  end

  desc 'db_migrate', 'run db migrate'
  def db_migrate
    system <<~Desc
      docker exec #{ops_container} rails db:migrate
    Desc
  end
end

# name: discourse-plugin-test
# about: Setup forum extension microservice 
# version: 0.0.1
# authors: Shaunak Das


load File.expand_path('../lib/connecpath_helper.rb', __FILE__)
load File.expand_path('../lib/connecpath_helper/engine.rb', __FILE__)

# And mount the engine
# Check out http://localhost:3000/endpoint/users/sample.json
Discourse::Application.routes.append do
  mount ::ConnecpathHelper::Engine, at: '/endpoint'
end
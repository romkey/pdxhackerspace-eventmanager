# Load custom OmniAuth strategies before the OmniAuth initializer runs
# The "00_" prefix ensures this runs first
#
# This is needed because:
# 1. Rails 7.1 autoloader expects directory names to match module names (case-sensitive)
# 2. We have lib/omniauth/ (lowercase) but module OmniAuth:: (capital A)
# 3. This must load before config/initializers/omniauth.rb tries to use it

require Rails.root.join("lib/omniauth/strategies/authentik").to_s

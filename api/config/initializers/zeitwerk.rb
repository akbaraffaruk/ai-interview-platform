# frozen_string_literal: true

# Zeitwerk derives constants from file names. The two Rack middlewares in
# app/channels are deliberately spelled with a capital S — AudioWebSocketMiddleware,
# CoverageWebSocketMiddleware — but their files are `*_websocket_middleware.rb`.
# Under eager loading (always in production, and in CI because GitHub Actions sets
# CI=true) that mismatch aborts boot with a Zeitwerk name error. The inflection
# keeps the intentional camel case and the existing file names.
#
# NOTE: Rails' autoloader inflector is keyed by the *whole* basename
# (Rails::Autoloaders::Inflector#camelize looks up `overrides[basename]`, falling
# back to `basename.camelize`), so a per-word mapping such as
# 'websocket' => 'WebSocket' would never match these file names. The full
# basenames are mapped instead.
Rails.autoloaders.main.inflector.inflect(
  'audio_websocket_middleware' => 'AudioWebSocketMiddleware',
  'coverage_websocket_middleware' => 'CoverageWebSocketMiddleware'
)

# frozen_string_literal: true

Rails.application.routes.draw do
  get "glsl_helper_test/show", to: "glsl_helper_test#show"
  get "glsl_helper_test/with_csp", to: "glsl_helper_test#with_csp"
  get "glsl_helper_test/nonce_suppressed", to: "glsl_helper_test#nonce_suppressed"
  get "glsl_helper_test/escape_test", to: "glsl_helper_test#escape_test"
end

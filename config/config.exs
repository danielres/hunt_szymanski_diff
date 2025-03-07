import Config

if Mix.env() == :dev do
  config :mix_test_watch,
    extra_extensions: [".txt"]
end

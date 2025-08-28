defmodule StarweaveWeb.Gettext do
  @moduledoc """
  A module providing Internationalization with a gettext-based API.

  By using [Gettext](https://hexdocs.pm/gettext),
  your module gains a set of macros for translations, for example:

      import StarweaveWeb.Gettext

      # Simple translation
      gettext("Here is the string to translate")

      # Plural translation
      ngettext("Here is the string to translate",
               "Here are the strings to translate",
               3)

      # Domain-based translation
      dgettext("errors", "This is an error message")
  """
  use Gettext.Backend, otp_app: :starweave_web

  # When your application starts, we need to compile the gettext files.
  # This is done by calling `mix gettext.extract` and `mix gettext.compile`.
  # We also need to ensure the gettext compiler is included in the :elixirc_paths.

  # To add a new language:
  # 1. Create a directory for the language in priv/gettext/
  # 2. Copy the default.pot file to that directory and rename it to .po
  # 3. Translate the strings in the .po file
  # 4. Run `mix gettext.compile`

  # Example:
  # mkdir -p priv/gettext/es/LC_MESSAGES
  # cp priv/gettext/default.pot priv/gettext/es/LC_MESSAGES/default.po
  # # Edit the .po file to add Spanish translations
  # mix gettext.compile

  # Then in your templates, you can use:
  # <%= gettext "Hello, %{name}!", name: @user.name %>

  # And in your code:
  # Gettext.put_locale(StarweaveWeb.Gettext, "es")

  # The default locale is set in config/config.exs:
  # config :starweave_web, StarweaveWeb.Gettext, default_locale: "en"
end

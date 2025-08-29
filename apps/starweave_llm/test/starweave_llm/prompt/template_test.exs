defmodule StarweaveLLM.Prompt.TemplateTest do
  use ExUnit.Case, async: true
  alias StarweaveLLM.Prompt.Template

  describe "render/2" do
    test "renders template with variables" do
      template = "Hello, {{name}}! How are you {{time_of_day}}?"
      variables = %{name: "Alice", time_of_day: "today"}
      
      assert {:ok, "Hello, Alice! How are you today?"} = Template.render(template, variables)
    end

    test "handles missing variables gracefully" do
      template = "Hello, {{name}}! How are you {{time_of_day}}?"
      variables = %{name: "Alice"}
      
      assert {:error, _} = Template.render(template, variables)
    end

    test "handles empty variables" do
      template = "Hello, {{name}}!"
      variables = %{}
      
      assert {:error, _} = Template.render(template, variables)
    end

    test "handles complex variable interpolation" do
      template = "User: {{user_message}}\nContext: {{context}}\nMemories: {{memories}}"
      variables = %{
        user_message: "What is the weather?",
        context: "Previous conversation about weather",
        memories: "Weather patterns from yesterday"
      }
      
      result = Template.render(template, variables)
      assert {:ok, rendered} = result
      assert rendered =~ "User: What is the weather?"
      assert rendered =~ "Context: Previous conversation about weather"
      assert rendered =~ "Memories: Weather patterns from yesterday"
    end
  end

  describe "render_template/3" do
    test "loads and renders template by name" do
      variables = %{user_message: "Hello", context: "Previous chat"}
      
      result = Template.render_template(:default, variables)
      assert {:ok, rendered} = result
      assert rendered =~ "You are STARWEAVE"
      assert rendered =~ "Hello"
    end

    test "handles template loading errors" do
      variables = %{user_message: "Hello"}
      
      result = Template.render_template(:nonexistent, variables)
      assert {:error, _} = result
    end
  end

  describe "load_template/2" do
    test "loads existing template" do
      result = Template.load_template(:default, "default")
      assert {:ok, content} = result
      assert content =~ "You are STARWEAVE"
    end

    test "handles missing template file" do
      result = Template.load_template(:nonexistent, "default")
      assert {:error, _} = result
    end
  end

  describe "validate_template/1" do
    test "extracts variables from template" do
      template = "Hello {{name}}, how are you {{time_of_day}}?"
      
      assert {:ok, variables} = Template.validate_template(template)
      assert "name" in variables
      assert "time_of_day" in variables
      assert length(variables) == 2
    end

    test "handles templates with no variables" do
      template = "Hello, world!"
      
      assert {:ok, variables} = Template.validate_template(template)
      assert variables == []
    end

    test "handles templates with whitespace in variables" do
      template = "Hello {{ name }}, how are you {{ time_of_day }}?"
      
      assert {:ok, variables} = Template.validate_template(template)
      assert "name" in variables
      assert "time_of_day" in variables
    end

    test "handles duplicate variables" do
      template = "Hello {{name}}, {{name}}! How are you {{name}}?"
      
      assert {:ok, variables} = Template.validate_template(template)
      assert variables == ["name"]
    end
  end

  describe "get_latest_version/1" do
    test "gets latest version of existing template" do
      result = Template.get_latest_version(:default)
      assert {:ok, version} = result
      assert version == "default"
    end

    test "handles template with no versions" do
      result = Template.get_latest_version(:nonexistent)
      assert {:error, _} = result
    end
  end
end


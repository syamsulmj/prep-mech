defmodule PrepMechWeb.SessionHTML do
  use PrepMechWeb, :html

  embed_templates "session_html/*"

  @doc "A pixel-themed text input bound to a form field."
  attr :field, Phoenix.HTML.FormField, required: true
  attr :label, :string, required: true
  attr :type, :string, default: "text"
  attr :rest, :global, include: ~w(autocomplete inputmode placeholder required)

  def pa_input(assigns) do
    ~H"""
    <div class="flex flex-col gap-1.5">
      <label
        for={@field.id}
        class="font-mono font-medium text-xs tracking-[0.16em] uppercase text-pa-amber"
      >
        {@label}
      </label>
      <input
        type={@type}
        id={@field.id}
        name={@field.name}
        value={Phoenix.HTML.Form.normalize_value(@type, @field.value)}
        class="pa-input"
        {@rest}
      />
      <p :for={msg <- @field.errors} class="text-xs text-pa-magenta">{translate_error(msg)}</p>
    </div>
    """
  end

  @doc "A pixel-themed select bound to a form field."
  attr :field, Phoenix.HTML.FormField, required: true
  attr :label, :string, required: true
  attr :options, :list, required: true

  def pa_select(assigns) do
    ~H"""
    <div class="flex flex-col gap-1.5">
      <label
        for={@field.id}
        class="font-mono font-medium text-xs tracking-[0.16em] uppercase text-pa-amber"
      >
        {@label}
      </label>
      <select id={@field.id} name={@field.name} class="pa-select">
        {Phoenix.HTML.Form.options_for_select(@options, @field.value)}
      </select>
      <p :for={msg <- @field.errors} class="text-xs text-pa-magenta">{translate_error(msg)}</p>
    </div>
    """
  end
end

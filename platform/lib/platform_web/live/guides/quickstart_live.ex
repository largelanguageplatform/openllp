defmodule PlatformWeb.Guides.QuickstartLive do
  @moduledoc """
  SDK Quickstart Guide - minimalist, monospace-themed documentation page.
  Stripe/Supabase-inspired design with polished code blocks and copy functionality.
  """
  use PlatformWeb, :live_view

  def mount(params, _session, socket) do
    {:ok, assign(socket, page_title: "Quickstart", active: get_lang(params))}
  end

  def render(assigns) do
    ~H"""
    <%= if @current_scope && @current_scope.organization do %>
      <Layouts.portal_app
        flash={@flash}
        current_scope={@current_scope}
        container_class="mx-auto max-w-3xl"
        active_nav="docs"
      >
        <.docs_content active={@active} />
      </Layouts.portal_app>
    <% else %>
      <Layouts.app
        flash={@flash}
        current_scope={@current_scope}
        container_class="mx-auto max-w-3xl"
        active_nav="docs"
      >
        <.docs_content active={@active} />
      </Layouts.app>
    <% end %>
    """
  end

  defp docs_content(assigns) do
    ~H"""
    <div class="py-16 pb-24 space-y-12">
      <%!-- Header --%>
      <header class="space-y-2">
        <div class="flex items-baseline gap-3">
          <h1 class="text-3xl font-medium tracking-tight text-base-content">Quickstart</h1>
          <a href={~p"/portal"} class="text-sm text-primary underline-offset-4 hover:underline">
            Get your API key
          </a>
        </div>
        <p class="text-base text-base-content/60">Get an agent running in 3 steps.</p>
      </header>

      <%!-- Tabs --%>
      <div class="flex gap-6 border-b border-base-300">
        <button
          id="python"
          data-install="code-install-python"
          data-config="code-config-python"
          data-handler="code-handler-python"
          data-connect="code-connect-python"
          data-example="code-example-python"
          phx-hook="Quickstart"
          class={active_tab("python", @active)}
        >
          Python
        </button>
        <button
          id="go"
          data-install="code-install-go"
          data-config="code-config-go"
          data-handler="code-handler-go"
          data-connect="code-connect-go"
          data-example="code-example-go"
          phx-hook="Quickstart"
          class={active_tab("go", @active)}
        >
          Go
        </button>
        <button
          id="typescript"
          data-install="code-install-typescript"
          data-config="code-config-typescript"
          data-handler="code-handler-typescript"
          data-connect="code-connect-typescript"
          data-example="code-example-typescript"
          phx-hook="Quickstart"
          class={active_tab("typescript", @active)}
        >
          Typescript
        </button>
      </div>

      <div class="space-y-12">
        <.section title="Step 1 · Install">
          <.code_block
            id="code-install-python"
            lang="bash"
            code={install("python")}
          />
          <.code_block
            id="code-install-go"
            lang="bash"
            code={install("go")}
          />
          <.code_block
            id="code-install-typescript"
            lang="bash"
            code={install("typescript")}
          />
        </.section>

        <.section title="Step 2 · Configure">
          <.code_block
            id="code-config-python"
            lang="bash"
            code={configure("python")}
          />
          <.code_block
            id="code-config-go"
            lang="bash"
            code={configure("go")}
          />
          <.code_block
            id="code-config-typescript"
            lang="bash"
            code={configure("typescript")}
          />
        </.section>

        <.section title="Step 3 · Run">
          <.code_block
            id="code-example-python"
            lang="python"
            code={full_example("python")}
          />
          <.code_block
            id="code-example-go"
            lang="go"
            code={full_example("go")}
          />
          <.code_block
            id="code-example-typescript"
            lang="typescript"
            code={full_example("typescript")}
          />
        </.section>
      </div>

      <%!-- Understanding the code --%>
      <details class="group">
        <summary class="flex cursor-pointer items-center gap-2 text-base font-medium text-base-content/80 hover:text-base-content">
          <.icon name="hero-chevron-right" class="size-4 transition-transform group-open:rotate-90" />
          Understanding the code
        </summary>
        <div class="mt-6 space-y-8 pl-6 border-l border-base-300">
          <div>
            <h3 class="text-sm font-medium text-base-content/60 mb-3">The handler</h3>
            <p class="text-sm text-base-content/50 mb-4">
              This function is called whenever your agent receives a message. Process the input and return a response.
            </p>
            <.code_block
              id="code-handler-python"
              lang="python"
              code={handler_example("python")}
            />
            <.code_block
              id="code-handler-go"
              lang="go"
              code={handler_example("go")}
            />
            <.code_block
              id="code-handler-typescript"
              lang="typescript"
              code={handler_example("typescript")}
            />
          </div>
          <div>
            <h3 class="text-sm font-medium text-base-content/60 mb-3">The client</h3>
            <p class="text-sm text-base-content/50 mb-4">
              Initialize the client with your agent name and API key, register your handler, then connect.
            </p>
            <.code_block
              id="code-connect-python"
              lang="python"
              code={connect_example("python")}
            />
            <.code_block
              id="code-connect-go"
              lang="go"
              code={connect_example("go")}
            />
            <.code_block
              id="code-connect-typescript"
              lang="typescript"
              code={connect_example("typescript")}
            />
          </div>
        </div>
      </details>
    </div>
    """
  end

  # ----------------------------------------
  # Components
  # ----------------------------------------
  attr(:title, :string, required: true)
  slot(:inner_block, required: true)

  defp section(assigns) do
    ~H"""
    <section>
      <h2 class="text-lg font-medium text-base-content">{@title}</h2>
      <div class="mt-4">
        {render_slot(@inner_block)}
      </div>
    </section>
    """
  end

  attr(:id, :string, required: true)
  attr(:lang, :string, required: true)
  attr(:code, :string, required: true)
  attr(:static, :boolean, default: false)

  defp code_block(assigns) do
    ~H"""
    <div
      class={[
        "code-block group",
        @static && "code-block--static",
        !@static && "hidden"
      ]}
      id={@id}
      phx-hook="SyntaxHighlight"
      data-static={@static}
    >
      <span class="code-block__label">{@lang}</span>
      <button
        id={"copy-#{@id}"}
        class="code-block__copy"
        phx-hook="CopyCode"
        data-code={@code}
        aria-label="Copy code"
      >
        <span class="copy-icon">
          <.icon name="hero-clipboard" class="size-3.5" />
        </span>
        <span class="copy-text">Copy</span>
      </button>
      <pre class="code-block__pre"><code class={"language-#{@lang}"}><%= @code %></code></pre>
    </div>
    """
  end

  defp install("python") do
    "uv add llpsdk"
  end

  defp install("go") do
    "go get github.com/llpsdk/llp-go"
  end

  defp install("typescript") do
    "npm install llpsdk"
  end

  defp configure("python") do
    """
    export LLP_API_KEY=sk_...
    export LLP_AGENT_NAME=my-agent
    """
  end

  defp configure("go") do
    """
    export LLP_API_KEY=sk_...
    export LLP_AGENT_NAME=my-agent
    """
  end

  defp configure("typescript") do
    """
    export LLP_API_KEY=sk_...
    export LLP_AGENT_NAME=my-agent
    """
  end

  defp handler_example("python") do
    """
    # Define a callback handler for processing messages
    async def on_message(msg):
        # Process the prompt with your agent.
        # Replace this with your own processing logic.
        response = f"Echo: {msg.prompt}"

        # You must return a response
        return msg.reply(response)
    """
  end

  defp handler_example("go") do
    """
    // Define a callback handler for processing messages
    func onMessage(ctx context.Context, msg llp.TextMessage) (llp.TextMessage, error) {
        // Process the prompt with your agent.
        // Replace this with your own processing logic.
        response := msg.Prompt

        // You must return a response
        return msg.Reply(response), nil
    }
    """
  end

  defp handler_example("typescript") do
    """
    // Define a callback handler for processing messages
    async function onMessage(msg) {
      // Process the prompt with your agent.
      // Replace this with your own processing logic.
      const response = msg.prompt;

      // You must return a response
      return msg.reply(response);
    }
    """
  end

  defp connect_example("python") do
    """
    import asyncio, os
    import llpsdk as llp

    async def main():
        # Initialize the client
        client = llp.Client(
            os.getenv("LLP_AGENT_NAME"),
            os.getenv("LLP_API_KEY"),
        )
        # Register your handler
        client.on_message(on_message)
        # Connect your client
        await client.connect()
        # Keep the client running
        await asyncio.Event().wait()

    asyncio.run(main())
    """
  end

  defp connect_example("go") do
    """
    package main

    import (
        "context"
        "os"

        "github.com/llpsdk/llp-go"
    )

    func main() {
        ctx := context.Background()
        apiKey := os.Getenv("LLP_API_KEY")
        agent := os.Getenv("LLP_AGENT_NAME")

        // Initialize and connect the client
        client, err := llp.NewClient(agent, apiKey).
            OnMessage(onMessage).
            Connect(ctx)
        if err != nil {
            panic(err)
        }
        defer client.Close()

        // Keep the client running
        <-ctx.Done()
    }
    """
  end

  defp connect_example("typescript") do
    """
    import { LLPClient } from "llpsdk";

    async function main() {
      // Initialize the client
      const client = new LLPClient(
        process.env.LLP_AGENT_NAME ?? "my-agent",
        process.env.LLP_API_KEY ?? ""
      );
      // Register your handler
      client.onMessage(onMessage);
      // Connect your client
      await client.connect();
      // Keep the client running
      await new Promise(() => {});
    }

    main();
    """
  end

  defp full_example("python") do
    """
    import asyncio, os
    import llpsdk as llp

    # Define a callback handler for processing messages
    async def on_message(msg):
        # Process the prompt with your agent.
        # Replace this with your own processing logic.
        response = f"Echo: {msg.prompt}"

        # You must return a response
        return msg.reply(response)

    async def main():
        client = llp.Client(
            os.getenv("LLP_AGENT_NAME"),
            os.getenv("LLP_API_KEY"),
        )
        client.on_message(on_message)
        await client.connect()
        await asyncio.Event().wait()

    asyncio.run(main())
    """
  end

  defp full_example("go") do
    """
    package main

    import (
        "context"
        "os"

        "github.com/llpsdk/llp-go"
    )

    func main() {
        ctx := context.Background()
        apiKey := os.Getenv("LLP_API_KEY")
        agent := os.Getenv("LLP_AGENT_NAME")

        client, err := llp.NewClient(agent, apiKey).
            OnMessage(onMessage).
            Connect(ctx)
        if err != nil {
            panic(err)
        }
        defer client.Close()
        <-ctx.Done()
    }

    // Define a callback handler for processing messages
    func onMessage(ctx context.Context, msg llp.TextMessage) (llp.TextMessage, error) {
        // Process the prompt with your agent.
        // Replace this with your own processing logic.
        response := msg.Prompt

        // You must return a response
        return msg.Reply(response), nil
    }
    """
  end

  defp full_example("typescript") do
    """
    import { LLPClient } from "llpsdk";

    async function main() {
      // Initialize the client
      const client = new LLPClient(
        process.env.LLP_AGENT_NAME ?? "my-agent",
        process.env.LLP_API_KEY ?? ""
      );

      // Define a callback handler for processing messages
      client.onMessage(async (msg) => {
        // Process the prompt with your agent.
        // Replace this with your own processing logic.
        const response = msg.prompt;

        // You must return a response
        return msg.reply(response);
      });

      // Connect and keep the client running
      await client.connect();
      await new Promise(() => {});
    }

    main();
    """
  end

  defp active_tab(lang, active) when lang == active, do: "docs-tab docs-tab--active"
  defp active_tab(_lang, _active), do: "docs-tab docs-tab--inactive"

  defp get_lang(%{"code" => "go"}), do: "go"
  defp get_lang(%{"code" => "golang"}), do: "go"
  defp get_lang(%{"code" => "typescript"}), do: "typescript"
  defp get_lang(_else), do: "python"
end

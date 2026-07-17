defmodule Platform.Chaos.Story do
  require Logger
  alias Platform.Admin.DomainPersona
  alias Platform.Chaos.Tools
  alias Platform.Chaos.Receipt
  alias Platform.Chaos.W2
  alias Platform.Chaos.NEC1099
  alias Platform.Chaos.BankStatement

  defstruct state: %{},
            goal: nil,
            progress: %{},
            persona: %DomainPersona{},
            llm_instance: nil

  @max_turns_ceiling 20

  def start(persona, opts \\ [])

  def start(%DomainPersona{name: "invoice"} = persona, opts) do
    llm_instance = initialize_llm(opts)
    {llm_mod, _llm} = llm_instance

    schemas = [
      &initial_schema/1,
      &invoice_products_schema/1,
      &clients_schema/1,
      &invoice_schema/1,
      &receipt_schema/1,
      &nec1099_schema/1,
      &bank_statement_schema/1,
      &w2_schema/1
    ]

    state = %{
      agent_name: persona.name
    }

    {state, _llm} = storybuilder(llm_instance, schemas, state)

    Logger.info(
      "Storybuilder complete. Document counts: invoices=#{state.total_invoices}, receipts=#{state.total_receipts}, 1099_nec=#{state.total_1099_nec}, bank_statements=#{state.total_bank_statements}, w2=#{state.total_w2}"
    )

    Logger.info("Storybuilder state keys: #{inspect(Map.keys(state))}")

    max_turns = min(persona.max_turns || 10, @max_turns_ceiling)

    %__MODULE__{
      persona: persona,
      state: state,
      progress: %{current_turns: 0, max_turns: max_turns} |> initialize_goal(persona, state),
      llm_instance: {llm_mod, llm_mod.init(:story) |> llm_mod.system(story(state))}
    }
  end

  def start(%DomainPersona{} = persona, opts) do
    {llm_mod, llm} = initialize_llm(opts)
    max_turns = min(persona.max_turns || 10, @max_turns_ceiling)

    state = %{
      agent_name: persona.name
    }

    %__MODULE__{
      persona: persona,
      state: state,
      progress: %{current_turns: 0, max_turns: max_turns} |> initialize_goal(persona, state),
      llm_instance: {llm_mod, llm |> llm_mod.system(persona.prompt_text)}
    }
  end

  def take_turn(%__MODULE__{progress: progress} = story) do
    if progress.current_turns == progress.max_turns do
      {:fail, :max_turns}
    else
      {:continue,
       story
       |> Map.merge(%{progress: Map.put(progress, :current_turns, progress.current_turns + 1)})}
    end
  end

  def progress_plot(%__MODULE__{llm_instance: llm_instance, progress: progress} = story, schema) do
    if progress.current_turns == 0 do
      prompt = dialogue_prompt(story, schema)

      {:ok, message, llm_instance} = loop_until_valid(llm_instance, prompt, schema, 3)
      {:continue, story} = take_turn(story)
      {message, story |> Map.merge(%{llm_instance: llm_instance})}
    else
      prompt = continue_dialogue_prompt(story, schema)

      {:ok, message, llm_instance} = loop_until_valid(llm_instance, prompt, schema, 3)
      {message, story |> Map.merge(%{llm_instance: llm_instance})}
    end
  end

  def evaluate_goal(%__MODULE__{llm_instance: llm_instance} = story, response) do
    prompt = goal_prompt(story, response, goal_schema())
    {:ok, goal, llm_instance} = loop_until_valid(llm_instance, prompt, goal_schema(), 3)

    Logger.info("Goal update: #{inspect(goal)}")

    case assert_goal(story, map_keys_to_atom(goal)) do
      {:continue, story} ->
        Logger.info("Progress: #{inspect(story.progress)}")
        {:continue, story |> Map.merge(%{llm_instance: llm_instance})}

      {:fail, reason} ->
        {:fail, reason}

      :passed ->
        :passed
    end
  end

  defp assert_goal(story, %{progressed: false}), do: {:continue, story}

  defp assert_goal(story, %{progressed: true, parameters: params}) do
    params
    |> Enum.reduce(
      {:continue, story},
      fn
        param, {:continue, story} ->
          g = Map.get(story.progress, String.to_atom(param.name))

          case update_goal(g, param) do
            %{assertion: :equal_to, current: c, target: t} when c == t ->
              :passed

            %{assertion: :less_than, current: c, target: t} when c < t ->
              :passed

            %{assertion: :greater_than, current: c, target: t} when c > t ->
              :passed

            %{assertion: :less_than_equal_to, current: c, target: t} when c <= t ->
              :passed

            %{assertion: :greater_than_equal_to, current: c, target: t} when c >= t ->
              :passed

            g ->
              p = Map.put(story.progress, String.to_atom(param.name), g)
              {:continue, story |> Map.merge(%{progress: p})}
          end

        _param, :passed ->
          :passed
      end
    )
  end

  defp update_goal(g, %{action: "add", value: val}),
    do: Map.merge(g, %{current: g.current + val})

  defp update_goal(g, %{action: "subtract", value: val}),
    do: Map.merge(g, %{current: g.current - val})

  defp update_goal(g, %{action: "set", value: val}), do: Map.merge(g, %{current: val})

  defp initialize_llm(opts) do
    llm_mod = Keyword.get(opts, :llm_mod, Platform.LLM)

    case Keyword.get(opts, :llm) do
      nil ->
        {llm_mod, llm_mod.init(:storybuilder, opts)}

      llm ->
        {llm_mod, llm}
    end
  end

  defp storybuilder({llm_mod, llm}, schemas, state) do
    llm =
      llm
      |> llm_mod.system(
        "Let's play the game 'Madlibs' where I provide a JSON schema, and you fill in the blanks. When we're finished, I will generate the final story. Attempt to make your answers succinct and as realistic as possible."
      )

    schemas
    |> Enum.reduce(
      {state, {llm_mod, llm}},
      fn schema, {state, llm_instance} ->
        case schema.(state) do
          {:llm_generate, schema} ->
            {:ok, resp, llm_instance2} =
              llm_instance
              |> loop_until_valid(chat_prompt(schema), schema, 5)

            {merge(resp, state), llm_instance2}

          {:manual, new_state} ->
            {merge(new_state, state), llm_instance}
        end
      end
    )
  end

  defp story(state) do
    """
    You are a freelancer (#{state.occupation}) running #{state.company.name}. You're chatting with
    your accountant to go over your docs. #{document_summary(state)}

    # How you talk
    You're busy and casual. Short messages, no jargon, no formality. Like texting a colleague.
    Examples:
    - "hey can you look at this invoice and make sure the amounts look right?"
    - "got a gas receipt from driving to a client thing last week, can i expense that?"
    - "here's my 1099 from last year, does that number match what i billed them?"
    - "sending over my bank statement, anything look off?"

    NEVER write long paragraphs. Keep it to 1-2 short sentences max.

    # Goal
    You need the accountant to actually LOOK AT each document and give you a real answer.
    Don't just hand things over — ask a specific question that forces them to examine it:
    - Invoice: "does this look right?" or "anything missing on this one?"
    - Receipt: "can i write this off?" or "is there anything on here i can't expense?"
    - 1099-NEC: "does this match what i invoiced them?" or "is the withholding correct?"
    - Bank statement: "anything weird on here?" or "do the deposits look right?"

    It is an automatic FAILURE if the accountant says it can't read your documents.
    The accountant can only see ONE attachment at a time.

    # Your Company:
    #{state.company.name} / #{state.company.address} / #{state.company.email}

    # Your Documents:

    #{story_documents(state)}
    """
  end

  defp document_summary(state) do
    parts =
      [
        if(state.invoices != [], do: "#{length(state.invoices)} invoice(s)"),
        if(state.receipts != [], do: "#{length(state.receipts)} receipt(s)"),
        if(state.nec1099s != [], do: "#{length(state.nec1099s)} 1099-NEC(s)"),
        if(state.bank_statements != [], do: "#{length(state.bank_statements)} bank statement(s)"),
        if(state.w2s != [], do: "#{length(state.w2s)} W-2(s)")
      ]
      |> Enum.reject(&is_nil/1)

    case parts do
      [] ->
        "You have no documents to provide."

      _ ->
        "You will provide the accountant: #{Enum.join(parts, ", ")}. DO NOT provide the same document more than once!"
    end
  end

  defp story_documents(state) do
    [
      if(state.invoices != [], do: "## Invoices\n\n#{story_invoices(state)}"),
      if(state.receipts != [], do: "## Receipts\n\n#{story_receipts(state)}"),
      if(state.nec1099s != [], do: "## 1099-NEC Forms\n\n#{story_nec1099s(state)}"),
      if(state.bank_statements != [],
        do: "## Bank Statements\n\n#{story_bank_statements(state)}"
      ),
      if(state.w2s != [], do: "## W-2 Forms\n\n#{story_w2s(state)}")
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n\n")
  end

  defp story_invoices(state) do
    for inv <- state.invoices do
      items =
        for item <- inv.items do
          "| #{item.description} | #{item.unit_price} | #{item.quantity} |"
        end
        |> Enum.join("\n")

      """
      Invoice: #{inv.invoice_number}
      Client: #{inv.to.name}
      Filename: #{inv.filename}
      URL: #{inv.attachment_url}
      Content Type: application/pdf
      Items:
      | Description | Price | Quantity |
      | ----------- | ----- | -------- |
      #{items}
      """
    end
    |> Enum.join("\n")
  end

  defp story_receipts(state) do
    for receipt <- state.receipts do
      """
      Receipt: #{receipt.receipt_number}
      Vendor: #{receipt.from.name}
      Total: $#{receipt.total}
      Filename: #{receipt.filename}
      URL: #{receipt.attachment_url}
      Content Type: application/pdf
      """
    end
    |> Enum.join("\n")
  end

  defp story_nec1099s(state) do
    for nec <- state.nec1099s do
      """
      1099-NEC from: #{nec.payer.name}
      Nonemployee Compensation: $#{nec.nonemployee_compensation}
      Filename: #{nec.filename}
      URL: #{nec.attachment_url}
      Content Type: application/pdf
      """
    end
    |> Enum.join("\n")
  end

  defp story_bank_statements(state) do
    for stmt <- state.bank_statements do
      """
      Bank: #{stmt.bank.name}
      Account: #{stmt.account_number}
      Period: #{stmt.statement_period.start} to #{stmt.statement_period.end}
      Filename: #{stmt.filename}
      URL: #{stmt.attachment_url}
      Content Type: application/pdf
      """
    end
    |> Enum.join("\n")
  end

  defp story_w2s(state) do
    for w2 <- state.w2s do
      """
      W-2 from: #{w2.employer.name}
      Wages: $#{w2.wages.box1_wages_tips_other}
      Filename: #{w2.filename}
      URL: #{w2.attachment_url}
      Content Type: application/pdf
      """
    end
    |> Enum.join("\n")
  end

  defp loop_until_valid(_llm, _prompt, _schema, 0) do
    Logger.error("loop_until_valid: exhausted all retry attempts, raising :invalid_response")
    raise {:error, :invalid_response}
  end

  defp loop_until_valid({llm_mod, llm}, prompt, schema, attempts) do
    Logger.debug(
      "loop_until_valid: #{attempts} attempts remaining, prompt length: #{String.length(prompt)}"
    )

    llm =
      llm
      |> llm_mod.chat(prompt, format: schema)

    msg =
      llm
      |> llm_mod.latest()

    Logger.debug(
      "loop_until_valid: LLM response (#{String.length(msg.content)} chars): #{String.slice(msg.content, 0, 500)}"
    )

    with {:ok, decoded} <- Jason.decode(msg.content),
         :ok <- ExJsonSchema.Validator.validate(schema, decoded) do
      {:ok, decoded, {llm_mod, llm}}
    else
      {:error, e = %Jason.DecodeError{}} ->
        Logger.warning(
          "loop_until_valid: JSON decode error (#{attempts - 1} retries left): #{Jason.DecodeError.message(e)}"
        )

        prompt = "JSON is not properly formatted: #{Jason.DecodeError.message(e)}"
        loop_until_valid({llm_mod, llm}, prompt, schema, attempts - 1)

      {:error, validation_errors} ->
        errors =
          validation_errors
          |> Enum.map(fn {description, path} -> "#{description} Path: #{path}" end)
          |> Enum.join("\n")

        Logger.warning(
          "loop_until_valid: schema validation failed (#{attempts - 1} retries left):\n#{errors}"
        )

        prompt = "JSON schema validation failed with the following errors:\n" <> errors <> "\n"
        loop_until_valid({llm_mod, llm}, prompt, schema, attempts - 1)
    end
  end

  defp merge(content, state) do
    content
    |> map_keys_to_atom()
    |> Enum.into(state)
  end

  def map_keys_to_atom(m) when is_list(m) do
    Enum.map(m, &map_keys_to_atom/1)
  end

  def map_keys_to_atom(m) when is_map(m) do
    Map.new(m, fn
      {k, v} ->
        ka =
          if is_atom(k) do
            k
          else
            String.to_atom(k)
          end

        cond do
          is_map(v) ->
            {ka, map_keys_to_atom(v)}

          is_list(v) ->
            {ka, map_keys_to_atom(v)}

          true ->
            {ka, v}
        end
    end)
  end

  def chat_prompt(schema) do
    """
    Return a response using the following JSON schema:
    #{Jason.encode!(schema)}
    """
  end

  def initial_schema(_state) do
    {:llm_generate,
     %{
       "title" => "freelancer",
       "description" => """
       Generate a story about a freelancer. Pick ONLY the document types that make sense:
       - Freelancers/contractors: invoices (they bill clients), 1099-NEC (received from clients), receipts (business expenses), bank_statement
       - Freelancers should NEVER have a W2 — they are not employees. Set total_w2 to 0.
       Set count to 0 for any document type that does not apply.
       """,
       "type" => "object",
       "properties" => %{
         "company" => %{
           "type" => "object",
           "description" => "freelancer company being invoiced",
           "properties" => %{
             "name" => %{
               "type" => "string",
               "description" => "name of the freelancer's company"
             },
             "address" => %{
               "type" => "string",
               "description" => "fake address of the freelancer's company"
             },
             "email" => %{
               "type" => "string",
               "description" => "email of the freelancer's company"
             }
           },
           "required" => ["name", "address", "email"]
         },
         "occupation" => %{
           "enum" => ["artist", "marketer", "writer", "designer"],
           "description" => "The kind of freelance work one performs"
         },
         "total_invoices" => %{
           "type" => "integer",
           "minimum" => 2,
           "maximum" => 2,
           "description" => "number of invoices this freelancer sends to clients"
         },
         "total_receipts" => %{
           "type" => "integer",
           "minimum" => 1,
           "maximum" => 1,
           "description" => "number of business expense receipts"
         },
         "total_w2" => %{
           "type" => "integer",
           "minimum" => 0,
           "maximum" => 1,
           "description" => "number of W-2 forms. Should be 0 for freelancers"
         },
         "total_1099_nec" => %{
           "type" => "integer",
           "minimum" => 0,
           "maximum" => 1,
           "description" => "number of 1099-NEC forms received from clients"
         },
         "total_bank_statements" => %{
           "type" => "integer",
           "minimum" => 0,
           "maximum" => 0,
           "description" => "number of monthly bank statements"
         }
       },
       "required" => [
         "company",
         "occupation",
         "total_invoices",
         "total_receipts",
         "total_w2",
         "total_1099_nec",
         "total_bank_statements"
       ]
     }}
  end

  def invoice_products_schema(state) do
    if state.total_invoices == 0 do
      {:manual, %{products: []}}
    else
      {:llm_generate,
       %{
         "title" => "invoice products",
         "description" =>
           "generate a random list of goods and services along with their costs as they relate to #{state.occupation}",
         "type" => "object",
         "properties" => %{
           "products" => %{
             "type" => "array",
             "minItems" => 3,
             "maxItems" => 10,
             "items" => %{
               "type" => "object",
               "properties" => %{
                 "description" => %{
                   "type" => "string",
                   "description" => "name of the product"
                 },
                 "unit_price" => %{
                   "type" => "number",
                   "description" => "price of the product or hourly rate if a service, in USD"
                 },
                 "quantity" => %{
                   "type" => "integer",
                   "minimum" => 1,
                   "description" => "quantity of the product or total hours if a service"
                 }
               },
               "required" => ["description", "unit_price", "quantity"]
             }
           }
         },
         "required" => ["products"]
       }}
    end
  end

  def clients_schema(state) do
    if state.total_invoices == 0 do
      {:manual, %{clients: []}}
    else
      {:llm_generate,
       %{
         "title" => "client list",
         "description" =>
           "generate a random list of clients that you've done business with as they relate to #{state.occupation}",
         "type" => "object",
         "properties" => %{
           "clients" => %{
             "type" => "array",
             "minItems" => 1,
             "maxItems" => state.total_invoices,
             "items" => %{
               "type" => "object",
               "properties" => %{
                 "name" => %{
                   "type" => "string",
                   "description" => "name of the company or person you did business with"
                 },
                 "address" => %{
                   "type" => "string",
                   "description" => "fake address of the company or person you did business with"
                 },
                 "email" => %{
                   "type" => "string",
                   "description" => "email of the company or person you did bussiness with"
                 }
               },
               "required" => ["name", "address", "email"]
             }
           }
         },
         "required" => ["clients"]
       }}
    end
  end

  def invoice_schema(state) do
    if state.total_invoices == 0 do
      {:manual, %{invoices: []}}
    else
      {:manual,
       %{
         invoices:
           for _ <- 1..state.total_invoices do
             total_products = length(state.products)
             count = Enum.random(1..total_products)

             request = %{
               agent_name: state.agent_name,
               invoice_number:
                 "INV-#{:rand.uniform(9999) |> Integer.to_string() |> String.pad_leading(4, "0")}",
               from: state.company,
               to: state.clients |> Enum.shuffle() |> List.first(),
               items: state.products |> Enum.shuffle() |> Enum.take(count),
               tax_rate: 0.08
             }

             {:ok, {location, filename}} =
               Tools.generate_attachment("storybuilder", request, "pdf")

             Enum.into(request, %{attachment_url: location, filename: filename})
           end
       }}
    end
  end

  def receipt_schema(state) do
    Logger.info("receipt_schema: total_receipts=#{state.total_receipts}")

    if state.total_receipts == 0 do
      {:manual, %{receipts: []}}
    else
      {:manual,
       %{
         receipts:
           for i <- 1..state.total_receipts do
             Logger.info("Generating receipt #{i}/#{state.total_receipts}...")
             customer = %{name: state.company.name}
             data = Receipt.generate(customer: customer)
             Logger.info("Receipt #{i} data generated, creating PDF...")
             {:ok, %{location: location, filename: filename}} = Receipt.generate_pdf(data)
             Logger.info("Receipt #{i} PDF created: #{filename}")
             Map.merge(data, %{"attachment_url" => location, "filename" => filename})
           end
       }}
    end
  end

  def nec1099_schema(state) do
    Logger.info("nec1099_schema: total_1099_nec=#{state.total_1099_nec}")

    if state.total_1099_nec == 0 do
      {:manual, %{nec1099s: []}}
    else
      {:manual,
       %{
         nec1099s:
           for i <- 1..state.total_1099_nec do
             Logger.info("Generating 1099-NEC #{i}/#{state.total_1099_nec}...")
             customer = %{name: state.company.name, address: state.company.address}
             data = NEC1099.generate(customer: customer)
             Logger.info("1099-NEC #{i} data generated, creating PDF...")
             {:ok, %{location: location, filename: filename}} = NEC1099.generate_pdf(data)
             Logger.info("1099-NEC #{i} PDF created: #{filename}")
             Map.merge(data, %{"attachment_url" => location, "filename" => filename})
           end
       }}
    end
  end

  def bank_statement_schema(state) do
    Logger.info("bank_statement_schema: total_bank_statements=#{state.total_bank_statements}")

    if state.total_bank_statements == 0 do
      {:manual, %{bank_statements: []}}
    else
      {:manual,
       %{
         bank_statements:
           for i <- 1..state.total_bank_statements do
             Logger.info("Generating bank statement #{i}/#{state.total_bank_statements}...")
             customer = %{name: state.company.name, address: state.company.address}
             data = BankStatement.generate(customer: customer)
             Logger.info("Bank statement #{i} data generated, creating PDF...")
             {:ok, %{location: location, filename: filename}} = BankStatement.generate_pdf(data)
             Logger.info("Bank statement #{i} PDF created: #{filename}")
             Map.merge(data, %{"attachment_url" => location, "filename" => filename})
           end
       }}
    end
  end

  def w2_schema(state) do
    Logger.info("w2_schema: total_w2=#{state.total_w2}")

    if state.total_w2 == 0 do
      {:manual, %{w2s: []}}
    else
      {:manual,
       %{
         w2s:
           for _ <- 1..state.total_w2 do
             customer = %{name: state.company.name, address: state.company.address}
             data = W2.generate(customer: customer)
             {:ok, %{location: location, filename: filename}} = W2.generate_pdf(data)
             Map.merge(data, %{"attachment_url" => location, "filename" => filename})
           end
       }}
    end
  end

  defp initialize_goal(goal, %DomainPersona{name: "invoice"}, state) do
    goal = Enum.into(goal, %{})

    goal =
      if state.total_invoices > 0,
        do:
          Map.put(goal, :opened_invoices, %{
            current: 0,
            target: state.total_invoices,
            assertion: :equal_to
          }),
        else: goal

    goal =
      if state.total_receipts > 0,
        do:
          Map.put(goal, :opened_receipts, %{
            current: 0,
            target: state.total_receipts,
            assertion: :equal_to
          }),
        else: goal

    goal =
      if state.total_1099_nec > 0,
        do:
          Map.put(goal, :opened_1099_nec, %{
            current: 0,
            target: state.total_1099_nec,
            assertion: :equal_to
          }),
        else: goal

    goal =
      if state.total_bank_statements > 0,
        do:
          Map.put(goal, :opened_bank_statements, %{
            current: 0,
            target: state.total_bank_statements,
            assertion: :equal_to
          }),
        else: goal

    goal =
      if state.total_w2 > 0,
        do:
          Map.put(goal, :opened_w2, %{current: 0, target: state.total_w2, assertion: :equal_to}),
        else: goal

    goal
  end

  # Fallback
  defp initialize_goal(goal, _persona, _state) do
    goal
    |> Enum.into(%{
      questions_answered: %{
        current: 0,
        target: 2,
        assertion: :greater_than_equal_to
      }
    })
  end

  defp dialogue_prompt(%__MODULE__{persona: %DomainPersona{name: "invoice"}}, schema) do
    """
    Send your first document to the accountant. Keep it short and casual — one or two sentences.
    Ask them a specific question that makes them actually look at it (not just "here you go").

    Respond using the following JSON schema:
    #{Jason.encode!(schema)}
    """
  end

  # Fallback
  defp dialogue_prompt(_story, schema) do
    """
    What is your first question for the agent?
    Respond using the following JSON schema:
    #{Jason.encode!(schema)}
    """
  end

  defp continue_dialogue_prompt(%__MODULE__{persona: %DomainPersona{name: "invoice"}}, schema) do
    """
    You still have docs to share. Send the next one — keep it casual and brief.
    Ask a question that forces them to actually examine it. Don't repeat yourself.

    Respond using the following JSON schema:
    #{Jason.encode!(schema)}
    """
  end

  # Fallback
  defp continue_dialogue_prompt(_story, schema) do
    """
    What is your next question for the agent?
    Respond using the following JSON schema:
    #{Jason.encode!(schema)}
    """
  end

  defp goal_prompt(
         %__MODULE__{
           progress: progress
         },
         response,
         schema
       ) do
    """
    The following is the latest response: #{response}

    # Goal Progress
    | Key | Value |
    | --- | ----- |
    #{format_goal_progress(progress)}

    Respond using the following JSON schema:
    #{Jason.encode!(schema)}
    """
  end

  defp format_goal_progress(progress) do
    goals = Map.drop(progress, [:current_turns, :max_turns])

    for {k, v} <- goals do
      "| #{k} | #{Map.get(v, :current)} |"
    end
    |> Enum.join("\n")
  end

  defp goal_schema() do
    %{
      "title" => "Goal progress evaluation",
      "description" => "Determine how the goal is progressing",
      "type" => "object",
      "properties" => %{
        "progressed" => %{
          "type" => "boolean",
          "description" =>
            "true if any progress has been made to any of the goals. False if no progress was made this round."
        },
        "explanation" => %{
          "type" => "string",
          "description" =>
            "If no progress has been made, give a brief explanation as to why and how it could have been corrected."
        },
        "parameters" => %{
          "type" => "array",
          "items" => %{
            "type" => "object",
            "properties" => %{
              "name" => %{
                "type" => "string",
                "description" => "Name of the goal being evaluated"
              },
              "action" => %{
                "enum" => ["add", "subtract", "set"],
                "description" =>
                  "What action to take on the goal's value. Add and subtract relative to the current value or set the absolute value."
              },
              "value" => %{
                "type" => "number",
                "description" =>
                  "If adding or subtracting, represents by how much. Otherwise, represents the value to set the goal at."
              }
            },
            "required" => ["name", "action", "value"]
          }
        }
      },
      "required" => ["progressed", "parameters"]
    }
  end
end

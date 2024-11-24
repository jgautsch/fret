# FReT: Forecasting through Recurrent Topology

Paper: [Time-series forecasting through recurrent topology](https://www.nature.com/articles/s44172-023-00142-8)

# Abstract

> Time-series forecasting is a practical goal in many areas of science and engineering. Common approaches for forecasting future events often rely on highly parameterized or black-box models. However, these are associated with a variety of drawbacks including critical model assumptions, uncertainties in their estimated input hyperparameters, and computational cost. All of these can limit model selection and performance. Here, we introduce a learning algorithm that avoids these drawbacks. A variety of data types including chaotic systems, macroeconomic data, wearable sensor recordings, and population dynamics are used to show that Forecasting through Recurrent Topology (FReT) can generate multi-step-ahead forecasts of unseen data. With no free parameters or even a need for computationally costly hyperparameter optimization procedures in high-dimensional parameter space, the simplicity of FReT offers an attractive alternative to complex models where increased model complexity may limit interpretability/explainability and impose unnecessary system-level computational load and power consumption constraints.

# Basic Usage:

```elixir
results = Fret.forecast()
vega = results |> Fret.plot_results()
```

To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix

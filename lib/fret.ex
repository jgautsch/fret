defmodule Fret do
  import Nx.Defn

  # -- Constants
  @forecast_horizon 100

  defn generate_sample_data do
    t = Nx.linspace(0.1, 70, n: 700)
    cos_comp = Nx.cos(2 * Nx.Constants.pi() * t / 3)
    sin_comp = 0.75 * Nx.sin(2 * Nx.Constants.pi() * t / 5)
    Nx.add(cos_comp, sin_comp)
  end

  defn split_data(data) do
    train = data[0..599]
    test = data[600..699]
    {train, test}
  end

  # Compute Euclidean distance matrix
  defn distance_matrix(x) do
    n = Nx.size(x)
    x_expanded = Nx.reshape(x, {n, 1})
    diffs = Nx.subtract(x_expanded, Nx.transpose(x_expanded))
    Nx.sqrt(Nx.pow(diffs, 2))
  end

  # Extract local topology using the 3x3 window agents
  defn extract_local_topology(padded_dm) do
    weights = Nx.tensor([2.0, 2.0, 4.0, 128.0, 0.0, 8.0, 64.0, 32.0, 16.0], type: :f32)
    {rows, cols} = Nx.shape(padded_dm)
    rows = rows - 2
    cols = cols - 2

    result = Nx.broadcast(0.0, {rows, cols})
    i = Nx.tensor(0, type: :s64)

    while {i, result, padded_dm, weights}, Nx.less(i, rows) do
      j = Nx.tensor(0, type: :s64)

      {_, new_result, pd, w, _} =
        while {j, result, padded_dm, weights, i}, Nx.less(j, cols) do
          window = Nx.slice(padded_dm, [i, j], [3, 3])
          center = window[1][1]
          comparison = Nx.greater_equal(window, center)
          flattened_comparison = Nx.reshape(comparison, {9})
          flattened_comparison = Nx.as_type(flattened_comparison, :f32)
          weighted_sum = Nx.sum(Nx.multiply(flattened_comparison, weights))
          weighted_sum = Nx.reshape(weighted_sum, {1, 1})
          new_result = Nx.put_slice(result, [i, j], weighted_sum)
          {j + 1, new_result, padded_dm, weights, i}
        end

      {i + 1, new_result, pd, w}
    end
    |> elem(1)
  end

  # Create layers based on thresholds
  defn create_layer(lt_output, lower_thresh, upper_thresh \\ 1.0e38, layer_value) do
    mask = Nx.equal(upper_thresh, 1.0e38)

    # Create both possible results
    infinite_case =
      lt_output
      |> Nx.greater_equal(lower_thresh)
      |> Nx.multiply(layer_value)

    finite_case =
      lt_output
      |> Nx.greater_equal(lower_thresh)
      |> Nx.logical_and(Nx.less(lt_output, upper_thresh))
      |> Nx.multiply(layer_value)

    # Select the appropriate result based on the mask
    Nx.select(mask, infinite_case, finite_case)
  end

  # Flatten layers
  defn flatten_layers(layers) do
    Nx.add(
      Nx.add(
        Nx.add(
          Nx.add(
            Nx.add(layers.layer1, layers.layer2),
            layers.layer3
          ),
          layers.layer4
        ),
        layers.layer5
      ),
      layers.layer6
    )
  end

  # Calculate similarity scores
  defn calculate_similarity(prior_states, current_state) do
    n = elem(Nx.shape(prior_states), 0)
    result = Nx.broadcast(0.0, {n, 1})

    while {idx = 0, acc = result, current_state, prior_states}, idx < n do
      state = prior_states[idx]
      similarity = Nx.mean(Nx.equal(current_state, state))
      # Reshape to match target dimensions
      similarity = Nx.reshape(similarity, {1, 1})
      new_acc = Nx.put_slice(acc, [idx, 0], similarity)
      {idx + 1, new_acc, current_state, prior_states}
    end
    |> elem(1)
  end

  # Find optimal threshold and archetypes
  defp find_archetypes(similarity_scores, x_train) do
    thresholds = Nx.linspace(0.61, 1.0, n: 40)
    threshold_list = Nx.to_flat_list(thresholds)
    scores_list = Nx.to_flat_list(similarity_scores)
    x_train_length = Nx.size(x_train)

    threshold_list
    |> Enum.map(fn threshold ->
      scores_list
      |> Enum.with_index()
      |> Enum.filter(fn {score, _idx} -> score >= threshold end)
      |> Enum.map(fn {_score, idx} -> idx end)
      |> then(fn indices ->
        if length(indices) >= 3 and length(indices) <= x_train_length / 4 do
          indices
        end
      end)
    end)
    |> Enum.reject(&is_nil/1)
    |> List.first()
    |> then(fn
      # Return a default tensor with index 0 if no archetypes found
      nil -> Nx.tensor([0])
      indices -> Nx.tensor(indices)
    end)
  end

  # Generate forecast using archetypes
  defn generate_forecast(x_train, archetypes) do
    n = Nx.size(archetypes)
    forecast_data = Nx.broadcast(0.0, {n, @forecast_horizon})

    while {idx = 0, acc = forecast_data, x_train, archetypes}, idx < n do
      archetype_idx = archetypes[idx]
      start_idx = archetype_idx + 3
      slice = Nx.slice(x_train, [start_idx], [@forecast_horizon])
      slice = Nx.reshape(slice, {1, @forecast_horizon})
      new_acc = Nx.put_slice(acc, [idx, 0], slice)
      {idx + 1, new_acc, x_train, archetypes}
    end
    |> elem(1)
    # Changed axis: 0 to axes: [0]
    |> then(&Nx.mean(&1, axes: [0]))
  end

  def forecast(data \\ nil) do
    data = if is_nil(data), do: generate_sample_data(), else: data
    {x_train, x_test} = split_data(data)

    # Calculate distance matrix
    dm = distance_matrix(x_train)

    # Pad distance matrix with edge_low, edge_high, and interior values for each dimension
    padded_dm = Nx.pad(dm, 0.0, [{1, 1, 0}, {1, 1, 0}])

    # Extract local topology
    lt_output = extract_local_topology(padded_dm)

    # Create layers
    layers = %{
      layer1: create_layer(lt_output, 42.5, 85.5, 1),
      layer2: create_layer(lt_output, 85.5, 127.5, 2),
      layer3: create_layer(lt_output, 127.5, 170.5, 3),
      layer4: create_layer(lt_output, 170.5, 212.5, 4),
      layer5: create_layer(lt_output, 212.5, 1.0e38, 5),
      layer6: create_layer(lt_output, 212.5, 1.0e38, 6)
    }

    # Flatten layers
    flattened = flatten_layers(layers)

    # Calculate similarity scores
    prior_states = flattened[0..-2//1]
    current_state = flattened[-1]
    similarity_scores = calculate_similarity(prior_states, current_state)

    # Find archetypes
    archetypes = find_archetypes(similarity_scores, x_train)

    # Generate forecast
    forecast = generate_forecast(x_train, archetypes)

    {forecast, x_test}
  end

  # Utility function to plot results using VegaLite
  def plot_results({forecast, actual}) do
    forecast_data = Nx.to_flat_list(forecast)
    actual_data = Nx.to_flat_list(actual)

    combined_data =
      (Enum.zip(0..(@forecast_horizon - 1), forecast_data)
       |> Enum.map(fn {x, y} -> %{"x" => x, "y" => y, "type" => "forecast"} end)) ++
        (Enum.zip(0..(@forecast_horizon - 1), actual_data)
         |> Enum.map(fn {x, y} -> %{"x" => x, "y" => y, "type" => "actual"} end))

    VegaLite.new(width: 600, height: 400)
    |> VegaLite.data_from_values(combined_data)
    |> VegaLite.mark(:line)
    |> VegaLite.encode_field(:x, "x", type: :quantitative)
    |> VegaLite.encode_field(:y, "y", type: :quantitative)
    |> VegaLite.encode_field(:color, "type", type: :nominal)
    |> VegaLite.to_spec()
  end
end

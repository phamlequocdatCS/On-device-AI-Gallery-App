import 'dart:math';

List<double> softmax(List<double> values) {
  if (values.isEmpty) {
    return [];
  }

  // Calculate the exponentials of each value
  List<double> exponentials = values.map((value) => exp(value)).toList();

  // Calculate the sum of all exponentials
  double sum = exponentials.reduce((a, b) => a + b);

  // Calculate the softmax values
  List<double> softmaxValues = exponentials.map((exp) => exp / sum).toList();

  return softmaxValues;
}

List<int> topKIndices(List<double> values, int k) {
  if (values.isEmpty || k <= 0) {
    return [];
  }

  List<MapEntry<int, double>> indexValuePairs =
      List.generate(values.length, (index) => MapEntry(index, values[index]));

  indexValuePairs.sort((a, b) => b.value.compareTo(a.value));

  return indexValuePairs.take(k).map((pair) => pair.key).toList();
}

List<double> normalizeDoubles(List<double> values) {
  // Compute the norm (magnitude) of the list
  double norm = sqrt(values.map((v) => v * v).reduce((a, b) => a + b));

  // Normalize each element by dividing by the norm
  return values.map((v) => v / norm).toList();
}

double dotProduct(List<double> a, List<double> b) {
  return List.generate(a.length, (i) => a[i] * b[i]).reduce((a, b) => a + b);
}

List<double> computeProbabilities(
  List<double> textEmbed,
  List<List<double>> imageEmbeds,
) {
  List<double> logits =
      imageEmbeds.map((image) => 100.0 * dotProduct(textEmbed, image)).toList();

  return softmax(logits);
}

int getMaxIndex(List<double> values) {
  double maxValue = values.reduce(max);
  return values.indexOf(maxValue);
}

int calculateCrossAxisCount(double maxWidth, double divisor) {
  return (maxWidth / divisor).floor();
}

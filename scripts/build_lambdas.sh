#!/usr/bin/env bash
set -e

LAMBDA_BUCKET=$1
REGION=$2

for dir in lambdas/*/; do
  NAME=$(basename "$dir")
  ZIP="/tmp/${NAME}.zip"

  echo "Packaging $NAME Lambda..."

  rm -f "$ZIP"

  if [ -f "$dir/pyproject.toml" ]; then
    echo "Installing from pyproject.toml"
    pip install "$dir" -t "$dir/package"
  elif [ -f "$dir/requirements.txt" ]; then
    echo "Installing from requirements.txt"
    pip install -r "$dir/requirements.txt" -t "$dir/package"
  else
    echo "Warning: No pyproject.toml or requirements.txt found in $dir"
    mkdir -p "$dir/package"

  fi  cp "$dir"/*.py "$dir/package/"

  cd "$dir/package"
  zip -r "$ZIP" .
  cd - >/dev/null

  aws s3 cp "$ZIP" "s3://$LAMBDA_BUCKET/${NAME}.zip" --region "$REGION"

  rm -rf "$dir/package"
done

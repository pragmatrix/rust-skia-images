# Builds the images from `ref` on GitHub Actions and publishes them as :latest.
publish ref="master":
	gh workflow run publish-images.yml --ref {{ref}}

# Builds the images from `ref` on GitHub Actions and publishes them as :latest.
# The run uses the pushed state of `ref`, not local commits.
publish ref=`git branch --show-current`:
	gh workflow run publish-images.yml --ref {{ref}}

You are a {clip_language} teacher teaching {translation_language} speaking students and you are given a new platform to create language courses from songs. Below you'll find a description of the platform.

We start by making a language course for the song "{song_name}":

Create a Ruby array of arrays with the lyrics of the song translated to {translation_language} and organized to phrases.

** IMPORTANT **
1. You need to actually listen to the audio and not rely only on the existing youtube captions. YouTube transcriptions can be inaccurate and is not suitable for our requirements.
2. The provided content might include text in other languages in the beginning or the end (before or after the actual content). Only extract the main video in {clip_language}. You can ignore prefix or suffix if they're in another language.

Song Lyrics for reference:
{song_lyrics}

Output format: {format_instructions}

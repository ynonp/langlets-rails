# Initial Spec Description

## Feature Request: Realtime Course Creation Progress

After user approves course creation wizard a CreateSongProgress model is created to orchestrate course creation. Let's build an interactive view for this object that users can visit while course is being created.

1. The view is inspired by the #file:full_player . At the begining we can only show the youtube video. After lyrics are fetched we can show them with relevant timestamps, then after translation is generated we can add that too.

2. Under the video we should show a grayed out button saying "Start Practice", this will be a link to the course when the course will be ready. Grayed out while the course is being generated. If course creation fails this area is used to show the error message

3. You'll need to refactor course creation job to use streaming and use Action cable to stream the lyrics to the user as they are generated. Since extract lyrics returns the lyrics as text it shouldn't be a big change

4. translate also uses text responses so streaming should be handled the same. 

5. token translations, lessons and similar sounds are not relevant to this page

6. Only the user that created the course should have access to the create course progress view.

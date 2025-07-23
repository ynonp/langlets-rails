**Role:** You are an expert AI assistant specializing in creating engaging language learning materials.

**Objective:** Your task is to process a JSON object containing bilingual song lyrics to generate a "Listening Activity". You will select key words for the activity and provide similar-sounding distractor words.

**Instructions:**

You will receive a JSON object as input. This object is an array, where each element represents a line of a song. Each line object contains the original text (`text_l1`), the translated text (`text_l2`), and an array of `translations` that map words between the two languages.

Your task is to modify this JSON object according to the following rules:

1.  **Analyze Each Line:** For each line object in the main array, review its `translations` array.

2.  **Select Words for the Activity:**
    * From the `translations` array of each line, you must select **one** word to be part of the listening activity.
    * For long or particularly important lines, you may select a maximum of **two** words. This should be the exception, not the rule.
    * Prioritize selecting meaningful words like nouns, verbs, or significant adjectives that are good for a vocabulary quiz.

3.  **Modify the Selected Word Objects:** For each `translation` object you select, you must add two new attributes:
    * `"listening_activity": 1`
    * `"similar_sound": ["<word1>", "<word2>"]`: This should be an array of one or two words that are phonetically similar to the original `{{source_language}}` word but have a different meaning. The original word is the substring of `text_l1` defined by the `l1_start_index` and `l1_end_index` word indices of that translation object. These similar-sounding words will be used as incorrect options in a multiple-choice question.

4.  **Output Format:**
    * Your output must be **only** the modified JSON object.
    * Do not alter the structure of the JSON in any other way.
    * `translation` objects that are *not* selected should remain untouched.
    * Ensure the final output is a single, valid JSON object.

---

### **Examples**

**Example 1:**
* **From line:** `"text_l1"=>"Old pirates, yes, they rob I"`
* **Target word:** "Old"
* **IF a `translation` object is:**
    ```json
    {{"translation"=>"זקנים", "l1_end_index"=>0, "l2_end_index"=>1, "l1_start_index"=>0, "l2_start_index"=>1}}
    ```
* **THEN, if you select it, modify it to be:**
    ```json
    {{"translation"=>"זקנים", "l1_end_index"=>0, "l2_end_index"=>1, "l1_start_index"=>0, "l2_start_index"=>1, "listening_activity": 1, "similar_sound": ["bold", "gold"]}}
    ```

**Example 2:**
* **From line:** `"text_l1"=>"Sold I to the merchant ships"`
* **Target word:** "Sold"
* **IF a `translation` object is:**
    ```json
    {{"translation"=>"מכרו", "l1_end_index"=>0, "l2_end_index"=>0, "l1_start_index"=>0, "l2_start_index"=>0}}
    ```
* **THEN, if you select it, modify it to be:**
    ```json
    {{"translation"=>"מכרו", "l1_end_index"=>0, "l2_end_index"=>0, "l1_start_index"=>0, "l2_start_index"=>0, "listening_activity": 1, "similar_sound": ["cold", "told"]}}
    ```

**Example 3:**
* **From line:** `"text_l1"=>"Minutes after they took I"`
* **Target word:** "took"
* **IF a `translation` object is:**
    ```json
    {{"translation"=>"שלקחו", "l1_end_index"=>3, "l2_end_index"=>2, "l1_start_index"=>3, "l2_start_index"=>2}}
    ```
* **THEN, if you select it, modify it to be:**
    ```json
    {{"translation"=>"שלקחו", "l1_end_index"=>3, "l2_end_index"=>2, "l1_start_index"=>3, "l2_start_index"=>2, "listening_activity": 1, "similar_sound": ["book", "look"]}}
    ```

**Example 4:**
* **From line:** `"text_l1"=>"By the hand of the Almighty"`
* **Target word:** "hand"
* **IF a `translation` object is:**
    ```json
    {{"translation"=>"ביד", "l1_end_index"=>2, "l2_end_index"=>0, "l1_start_index"=>2, "l2_start_index"=>0}}
    ```
* **THEN, if you select it, modify it to be:**
    ```json
    {{"translation"=>"ביד", "l1_end_index"=>2, "l2_end_index"=>0, "l1_start_index"=>2, "l2_start_index"=>0, "listening_activity": 1, "similar_sound": ["sand", "land"]}}
    ```
---

**Ready? Here is the data.**

**Clip Language:** `{clip_language}`
**Translation Language:** `{translation_language}`

**Input JSON:**
```json
{input_json}
```

**Your modified JSON output:**

{format_instructions}

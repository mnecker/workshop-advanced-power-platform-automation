# Lab 03: Custom Code in Logic Apps and Connectors

## Exercise Overview

In this lab, you will complete the following tasks:

1. Generate and import a sample contacts.csv file that contains 2000 contact records with personal information into your Dataverse developer instance.
2. Create a Logic App to calculate age statistics (average, median, and mean ages) across the imported contacts.
3. Extend the Logic App with a script step to perform faster cost-effective statistical calculations.
4. Bonus task: create a custom connector that performs statistical calculations. Connector can be used in Power Automate and Logic Apps.

## Task 1: Create and import sample contacts.csv file into Dataverse

First, you'll need to create a sample contacts.csv file with 2000 records containing first name, last name, email, and birthdate:

```csv
FirstName,LastName,Email,Birthdate
John,Doe,john.doe@example.com,1980-05-15
Jane,Smith,jane.smith@example.com,1992-09-22
# ... (remaining records)
```

### Easy way out

<details>
  <summary><span style="font-size:200%;">🧞</span> Show me the way</summary>

  Download the [sample contact.csv file](assets/contact.csv).

</details>

### Standard way

1. Use GenAI tool of your choice, e.g. Microsoft Copilot, ChatGPT, Claude with the following prompt:

```text
Generate a contact.csv file containing a sample set of 2000 contact records containing
first name, last name, email, birthdate. Birthdate should be in the range from 13 years
to 99 years old. Emails should include some email addresses with single quotes and some
with + signs. There should be no duplicate emails in the dataset.
```

1. Import into Dataverse

   - Log in to your Power Platform admin center

   - Navigate to your developer environment

   - Go to "Data" > "Tables"

   - Select the "Contact" table

   - Click "Import data" > "Import from Excel/CSV"

   - Upload your contacts.csv file

   - Map the columns to the appropriate fields in the Contact entity

   - Complete the import process

> [!TIP]
> Switch off duplicate detection rules for names:
> 
> 1. Open https://make.powerapps.com/ and switch to your environment
> 2. Select **Apps**, then select **All**.
> 3. Hover over **Power Platform Environment Settings** and press Play icon ▶️.
> 4. Select **Data Management** then select **Duplicate detection rules**.
> 5. Select **Contacts with the same first name and last name** rule and click **Unpublish**. 

## Task 2: Create a Logic App to calculate age statistics

### Logic App Creation Steps:

1. **Navigate to Azure Portal** https://portal.azure.com and create a new Logic App:

   - Search for "Logic App" in the Azure portal.
   - Click "Add" to create a new Logic App.
   - Select **Consumption** plan
   - Enter the following data:
     - Resource group: **rgdevN** where N is your assigned number
     - Name: name of your choice , for example, **aggregateN** 
     - Region: **North Europe**
   - Click "Review + create" and then "Create"
   - Select **Edit**

2. **Configure your Logic App with the following steps**:

   a. **Trigger**: Use **When HTTP Request is received**.

   b. **Connect to Dataverse and retrieve contacts**:

   - Add a new step: "Dataverse - List rows".
   - Create connection to your Dataverse instance if required.
   - Select "Contacts" as the table.

   c. **Initialize Variables**:

   - Initialize an array variable called `ages` (Type: Array).
   - Initialize an integer variable called `totalAge` (Type: Integer, Value: 0).
   - Initialize an integer variable called `count` (Type: Integer, Value: 0).

   d. **Loop through contacts**:

   - Add a "For each" control.

   - Select the "value" output from the List rows action.

   - Inside the loop:

     - Add an "Append to array variable" action:

       - Variable: `ages`.

       - Value: Use an expression to calculate the age:

         `div(sub(ticks(utcNow()),ticks(item()?['birthdate'])),31536000000000)`

     - Add an "Increment variable" action:

       - Variable: `count`.
       - Value: 1.

     - Add a "Set variable" action:

       - Variable: `totalAge`.

       - Value:

         `add(variables('totalAge'), div(sub(ticks(utcNow()),ticks(item()?['birthdate'])),31536000000000))`

   e. **Sort the ages array**:

   - Add a "Compose" action to sort the `ages` array:

     - Inputs:

       `sort(variables('ages'))`

     - Save the output of this action as `sortedAges`.

   f. **Calculate the median**:

   - Add a "Compose" action to calculate the median:

     - Inputs:

       `if(equals(mod(length(outputs('sortedAges')), 2), 0), div(add(outputs('sortedAges')[sub(div(length(outputs('sortedAges')), 2), 1)], outputs('sortedAges')[div(length(outputs('sortedAges')), 2)]), 2), outputs('sortedAges')[div(length(outputs('sortedAges')), 2)])` 


## Task 3: Add code step to calculate statistics

Add a "Run C# Script" step after the loop in your Logic App. This step will calculate the average, median, and mean ages based on the JSON data retrieved from the previous step.

### Prerequisites
Inline scripts require the Logic Apps instance to be linked to Azure Integration Account. 

1. Search for an Integration Account and create if required.
2. Navigate to Logic Apps settings
3. Select Integration account and save.

### JavaScript for Logic Apps

```csharp
var contacts = workflowContext.actions.GetContacts.outputs.body.value;
var today = new Date();

var ages = contacts
    .filter(function(c) {
        return c.birthdate && !isNaN(Date.parse(c.birthdate));
    })
    .map(function(c) {
        var birthdate = new Date(c.birthdate);
        var age = (today - birthdate) / (1000 * 60 * 60 * 24 * 365.25);
        return Math.floor(age);
    });

if (ages.length === 0) {
    return { error: "No valid birthdates found in the input data." };
}

// Calculate average
var total = ages.reduce(function(a, b) { return a + b; }, 0);
var averageAge = total / ages.length;

// Calculate median
ages.sort(function(a, b) { return a - b; });
var medianAge;
var mid = Math.floor(ages.length / 2);
if (ages.length % 2 === 0) {
    medianAge = (ages[mid - 1] + ages[mid]) / 2;
} else {
    medianAge = ages[mid];
}

return {
    TotalContacts: ages.length,
    AverageAge: averageAge,
    MedianAge: medianAge
};
```

### Steps to Add the JavaScript in Logic Apps

1. **Add a "Inline Script" action**:
   - In your Logic App, after the loop step, add a new action.
   - Search for "Inline Script" and select it.
2. **Paste the script**:
   - Copy the script above and paste it into the "Code" section of the "Inline JavaScript" action.
3. **Save and test your Logic App**:
   - Save the Logic App and trigger it manually or according to your recurrence settings.
   - Verify the output of the "Inline JavaScript" step to ensure the statistics are calculated correctly.

### Complete the Logic App:

1. **Add a "Response" action** to return the results:
   - Status Code: 200
   - Content-Type: application/json
   - Body: Output from the code step
2. **Save and test your Logic App** by triggering it manually or according to your recurrence settings.

## Expected Results

The final Logic App will:

1. Retrieve all contacts from Dataverse
2. Calculate ages for all contacts
3. Compute the average (mean), median, and mode age values
4. Return these statistics as a JSON response

This implementation provides comprehensive age statistics analysis for your imported contact records.

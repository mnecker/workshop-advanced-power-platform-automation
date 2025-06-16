# Lab 01: Dataverse Contact Age Analytics

## Exercise Overview

In this lab, you will complete the following tasks:

1. Generate and import a sample contacts.csv file that contains 2000 contact records with personal information into your Dataverse developer instance.
2. Create a Logic App to calculate age statistics (average, median, and mean ages) across the imported contacts.
3. Extend the Logic App with a script step to perform faster cost-effective statistical calculations.
4. Bonus task: create a custom connector that performs statistical calculations. Connector can be used in Power Atuomate and Logic Apps.

<details>
  <summary>🧑‍🏫 Prerequisites</summary>

## Power Apps Developer Environment
The Power Apps Developer Environment is a free, personal environment that allows you to build and test apps, flows, and other solutions using Microsoft Power Platform. It provides a sandbox for developers to experiment with Dataverse, Power Apps, Power Automate, and more.
To get started, you need to create a Power Apps Developer Environment if you don't have one already. Follow these steps:

1. Go to the [Power Apps Developer Plan](https://powerapps.microsoft.com/developerplan/) page.
2. Sign in with your Microsoft account or create a new one.
3. Click on "Get started" to create your developer environment.
4. Once created, you can access your environment from the Power Apps portal at [make.powerapps.com](https://make.powerapps.com).
5. In the Power Apps portal, you can create and manage your apps, flows, and data tables.

</details>

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
  <summary>🧞 Show me the way</summary>

  Download the [sample contact.csv file](assets/contact.csv).

</details>

### Standard way

1. Use GenAI tool of your choice, e.g. Microsoft Copilot, ChatGPT, Claude with the following prompt:

```text
Generate a contact.csv file containing a sample set of 2000 contact records containing first name, last name, email, birthdate. Birthdate should be in the range from 13 years to 99 years old. Emails should include some email addresses with single quotes and some with + signs
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

   - Add a new step: "Dataverse - List rows."
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

### C# Script for Logic Apps

```csharp
#r "Newtonsoft.Json"

using System;
using System.Linq;
using System.Collections.Generic;
using Newtonsoft.Json;

public class Contact
{
    public string Birthdate { get; set; }
}

public static async Task<object> Run(dynamic input, ILogger log)
{
    // Parse the input JSON
    var contacts = JsonConvert.DeserializeObject<List<Contact>>(input.ToString());

    // Calculate ages
    var ages = contacts
        .Where(c => DateTime.TryParse(c.Birthdate, out _))
        .Select(c => {
            var birthdate = DateTime.Parse(c.Birthdate);
            var today = DateTime.UtcNow;
            return (int)((today - birthdate).TotalDays / 365.25);
        })
        .ToList();

    if (ages.Count == 0)
    {
        return new { error = "No valid birthdates found in the input data." };
    }

    // Calculate average (mean)
    var averageAge = ages.Average();

    // Calculate median
    ages.Sort();
    double medianAge;
    if (ages.Count % 2 == 0)
    {
        medianAge = (ages[ages.Count / 2 - 1] + ages[ages.Count / 2]) / 2.0;
    }
    else
    {
        medianAge = ages[ages.Count / 2];
    }

    // Return the results
    return new
    {
        TotalContacts = ages.Count,
        AverageAge = averageAge,
        MedianAge = medianAge
    };
}
```



### Steps to Add the C# Script in Logic Apps

1. **Add a "Run C# Script" action**:
   - In your Logic App, after the loop step, add a new action.
   - Search for "Run C# Script" and select it.
2. **Paste the C# script**:
   - Copy the script above and paste it into the "Code" section of the "Run C# Script" action.
3. **Pass the JSON data**:
   - In the "Inputs" section, pass the JSON array of contacts retrieved from the previous step.
4. **Save and test your Logic App**:
   - Save the Logic App and trigger it manually or according to your recurrence settings.
   - Verify the output of the "Run C# Script" step to ensure the statistics are calculated correctly.

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

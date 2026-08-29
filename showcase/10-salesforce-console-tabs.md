# Salesforce Console Tabs Causing Browser Instability

## Executive summary

A user reported that Microsoft Edge eventually crashed while using Salesforce, because records continually accumulated as application tabs.

Rather than accepting "Edge keeps crashing" as the root cause, the behavior was reproduced and compared across different Salesforce navigation paths — which relocated the problem from the browser to the application's own workspace design.

## User symptom

```
Open record
Open record
Open record
Open record
...
Edge eventually becomes unstable
```

The user had been manually clearing Salesforce tabs to cope.

## Reproduction

The problem was reproduced independently on other machines. That immediately established:

```
Not unique to the user's PC
```

The behavior occurred in Salesforce console-style applications, including the Sales Console and Service Console.

## Workflow comparison

Different navigation paths were tested:

- Opening records from some Salesforce search/navigation paths created **persistent workspace tabs**.
- Opening records from **reports** did not produce the same accumulation.

This was the critical clue: the browser was the same, the Salesforce tenant was the same — only the *navigation context* changed.

## Root cause area

Salesforce Console navigation maintains records as workspace tabs **by design**. For this workflow, that design caused tabs to accumulate indefinitely.

The browser was experiencing the consequences. It was not the system originating the behavior.

## Resolution

A Salesforce application configuration change stopped the problematic Sales workflow from accumulating tabs the same way. The instability disappeared without touching the browser at all.

## Troubleshooting lesson

```
Symptom:            "Browser crashes"
Weak conclusion:    "Browser problem"
Better question:    "What workload is causing the browser
                     to consume resources?"
```

## Technologies

Salesforce · Salesforce Console navigation · Microsoft Edge · SaaS application configuration

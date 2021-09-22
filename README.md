# AWS Metrics, Alarms and Alerts
## AWS Metrics Dashboard
1. On the **Cloudwatch** page, go to `Dashboards` and `Create dashboard`
    - Give the dashboard
    - *The `Add widget` page is immeadiatley shown when you are taken into the dashboard page*
2. To add a widget, select `Add widget`
3. On the `Add widget` page, select the type of widget you want to add *(for something like CPU utilization, a line widget is best)*
4. Select the metric or log that you want to observe
5. Select `Create widget`. The widget will now be shown on the dashboard. The widgets can be renamed, resized and moved.
6. Mutiple widgets can be added to the dashboard so that any number of metrics can be observed. This gives really good insight into a systems status.

## AWS Alarms
1. On the **Cloudwatch** page, go to `All alarms` and `Create alarm`
2. Select the metric you want to have an alarm for
3. Configure the alarm
    - Configuire the metric that is measured
        - Give it a name
        - Select the statistic type
        - Select the period *(the sample rate of the measurement)*
    - Configure the conditions of the alarm
        - Choose the threshold type
        - Choose the relational operator *(>, >=, <=, <)*
        - Define the threshold
4. Configure the notification settings
    - Select or create a topic
    - *(optional)* Select an Auto Scaling action
        - Select an Auto Scaling group
        - Select a policy to execute
5. Select `Next` and give the alarm a name an description
6. Review all the options and select `Create alarm`

## Configuring AWS SNS (Simple Notification Service)
1. Go to the AWS SNS page and select `Topics` on the sidebar
2. Select `Create topic`
3. Configure the topic
    - Select a type, choose a name and a display name
    - *Selecting `FIFO` type will restrict the __subscription protocol__ to `Amazon SQS`*
    - Select `Create topic`
4. Configure the __subscription__ of the topic
    - On the topic page, select `Create subscription` *(if you create the subscription independently, you must provide a topics `ARN`)*
    - Select the protocol *(e.g. Email)*
    - Configure the `Endpoint` *(e.g. the email address to send the notification to)*
    - Select `Create subscription`
5. Confirm the subscription
    - An email will automatically be sent to the chosen email address, with the title being the chosen display name. The email will include a link to `Confirm subscription`. 
    - To manually test a subscription and send a confirmation email, go to `Topics` on the sidebar, select your topic and select `Publish message`. Give the email a subject and select `Publish message`. Again, an email will be sent to the selected email address with a confirmation link.
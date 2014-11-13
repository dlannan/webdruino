#include <Arduino.h>
void setup()
{
  pinMode(13, OUTPUT);
}


void loop()
{
  delay((200));
  digitalWrite(13,HIGH);
  delay((100));
  digitalWrite(13,LOW);

}
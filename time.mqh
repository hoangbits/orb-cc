//+------------------------------------------------------------------+
//|                                                  time.mqh   |
//|                        Copyright 2024, Hoang Le                   |
//|                                             https://www.yourwebsite.com |
//+------------------------------------------------------------------+

bool IsInTesterMode()
{
   return (bool)MQLInfoInteger(MQL_TESTER);
}



void print_current_tz() {
    datetime localTime = TimeLocal();
    // server time zone is likely not to be GMT+1. it's likely to be +3
    // so current timezone calculation might be wrong
   datetime gmt_Time = TimeGMT(); 
   //datetime serverTime = TimeCurrent(); 
   // 3600 is total second per hour
  
   int timeZoneOffset = (int)((localTime - gmt_Time) / 3600);
   
   string timeZoneString = "GMT" + (timeZoneOffset >= 0 ? "+" : "") + IntegerToString(timeZoneOffset);
   
   Print("Current timezone: ", timeZoneString);
}





//v2 
// https://claude.ai/chat/863685d7-7e58-4952-b257-c2045c15f2f8
// Gets the local time and GMT offset.
// Calls IsEDT() to determine if it's currently EDT or EST.
// Calculates the Eastern Time offset (-4 hours for EDT, -5 for EST).
// Adjusts the local time to Eastern Time and returns it.

// NOTE: can not using logic below to create convert_time_to_est(datetime server_time) as TimeGMT() might return data from the past
datetime GetCurrentEasternTime()
{
   // Get the current broker's server time
    datetime serverTime = TimeCurrent();
    
    // NOTE: it's wrong
    // Get the GMT offset of the server time
    //int gmtOffset = TimeGMTOffset(); // -25200 , -7 UTC is incorrect ----> using TimeGMT() to calculate. 
    
    // Get the true GMT time
    // https://itsfoss.com/wrong-time-dual-boot/
    // timedatectl set-local-rtc 1
    // return correct GMT time after correct dual boot window and ubuntu
    datetime gmtTime = TimeGMT();// correct
    
    
    // knowing serverTime and gmtTime -> can calculate server_time_offset
    // Calculate the real GMT offset
    //int server_time_offset = (int)(serverTime - gmtTime);
    int server_time_offset_not_round = (int)(serverTime - gmtTime);
    
    int server_time_offset = (int)MathRound((double)server_time_offset_not_round / 3600) * 3600;
    
    // Print("GetCurrentEasternTime::gmtOffset ", server_time_offset ); // return 10800, means +3 UTC is likely to be correct
    
    
    // Determine if it's EDT or EST
    bool isEDT = IsEDT(serverTime);
    // EDT typically starts on the second Sunday of March at 2:00 AM.
    // EDT typically ends on the first Sunday of November at 2:00 AM.
    // in EDT: the diff is smaller. Mar - Nov. Other wise the diff to Eastern time is bigger.
    // both from vietnam 11(EDT)- 12hours(EST). and London
    int easternOffset = isEDT ? -4 * 3600 : -5 * 3600;
    
    if(IsInTesterMode()) {
     server_time_offset =  3 * 3600 ;
    }
    
    // ftmo 17:45 is EDT 10:45
    // selft note FTMO is GMT +3
    // on summer: EDT is -4 
    // so the diff is 7 hours and FTMO is onner    
    // on summer it should convert 17:45 is EDT 10:45
   
    // IsInTesterMode true then server_time_offset will be 0
    // IsInTesterMode false then server_time_offset will be 3 * 3600
    
    int timeDifference = server_time_offset - easternOffset;
    //Print("GetCurrentEasternTime timeDifference:", timeDifference);
    // Adjust the server time to EST
    datetime easternTime = serverTime - timeDifference;
    
    //Print("GetCurrentEasternTime:: Current Eastern Time: ", TimeToString(easternTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS));

    return easternTime;
}


datetime convert_estern_time_to_server_time(datetime estern_time) {
    Print("convert_estern_time_to_server_time estern_time: ", estern_time);
    
    datetime serverTime = TimeCurrent();
    datetime gmtTime = TimeGMT();    
    
    int server_time_offset_not_round = (int)(serverTime - gmtTime);
    
    int server_time_offset = (int)MathRound((double)server_time_offset_not_round / 3600) * 3600;

   // datetime time_start = TimeCurrent();
    //int server_time_offset = (int)(time_start - TimeGMT());
    
    if(IsInTesterMode()) {
     server_time_offset =  3 * 3600 ;
    }
    bool isEDT = IsEDT(serverTime);    
    int easternOffset = isEDT ? -4 * 3600 : -5 * 3600;    
    int timeDifference = server_time_offset - easternOffset;
    //Print("convert_estern_time_to_server_time serverTime : ", serverTime );
    //Print("convert_estern_time_to_server_time gmtTime : ", gmtTime );
    //Print("convert_estern_time_to_server_time server_time_offset : ", server_time_offset );
    //Print("convert_estern_time_to_server_time easternOffset : ", easternOffset );
    //Print("convert_estern_time_to_server_time timeDifference : ", timeDifference );
    datetime server_time = estern_time + timeDifference;
    Print("convert_estern_time_to_server_time server_time: ", server_time);
    return server_time;
}




// issue when run backtest is: TimeGMT and TimeCurrent is the same.
// while they normally 3 hours diff based on broker
// Assume server_time is +3 GMT
datetime convert_server_time_to_est(datetime server_time)
{
   
    int server_time_offset = 3 * 3600;
    
    
    // Determine if it's EDT or EST
    bool isEDT = IsEDT(server_time);
    // EDT typically starts on the second Sunday of March at 2:00 AM.
    // EDT typically ends on the first Sunday of November at 2:00 AM.
    // in EDT: the diff is smaller. Mar - Nov. Other wise the diff to Eastern time is bigger.
    // both from vietnam 11(EDT)- 12hours(EST). and London
    int easternOffset = isEDT ? -4 * 3600 : -5 * 3600;
    

    // ftmo 17:45 is EDT 10:45
    // selft note FTMO is GMT +3
    // on summer: EDT is -4 
    // so the diff is 7 hours and FTMO is onner    
    // on summer it should convert 17:45 is EDT 10:45
   
    int timeDifference = server_time_offset - easternOffset;
    
    // Adjust the server time to EST
    //Print("convert_servertime_to_est timeDifference:", timeDifference);
    datetime easternTime = server_time - timeDifference;
    
    //Print("GetCurrentEasternTime:: Current Eastern Time: ", TimeToString(easternTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS));

    return easternTime;
}


int shift_bar_from_midnight_est_to_prev_day(){
   datetime serverTime = TimeCurrent();
   bool isEDT = IsEDT(serverTime);   
   // assume broker using GMT +3 
   if(isEDT) {
     return 7;
   }else {
     return 8;
   }
}



void debug_server_time() {
   Print("-------------------------START debug_server_time------------------");
   datetime time_local = TimeLocal();
   datetime time_current = TimeCurrent();
   datetime time_gmt = TimeGMT();
   Print("local computer time::TimeLocal() ", time_local);
   Print("server time::TimeCurrent() ", time_current);
   Print("+UTC time time_gmt::TimeGMT() ", time_gmt);
   
   //int TimeGMTOffset = TimeGMTOffset();  
   //Print("TimeGMTOffset :", TimeGMTOffset); // return wrong -25200 means -7UTC is incorrect
    
   datetime est_time = GetCurrentEasternTime();   
   Print("GetCurrentEasternTime ", est_time );
   
   //datetime serverTime = TimeCurrent();
   datetime yesterday = TimeCurrent() - PeriodSeconds(PERIOD_D1);
   datetime converted_yesterday_to_est = convert_server_time_to_est(yesterday);
   Print("yesterday ", yesterday);
   Print("converted_yesterday_to_est ", converted_yesterday_to_est);
   
   datetime d1CandleTime = iTime("GBPUSD", PERIOD_D1, 0);  
   Print("d1CandleTime yesterday ", d1CandleTime);
   //print_current_tz();   
   Print("-------------------------END debug_server_time------------------");
}







// Takes a date as input.
// Calculates the start and end dates of EDT for the given year.
// EDT typically starts on the second Sunday of March at 2:00 AM.
// EDT typically ends on the first Sunday of November at 2:00 AM.
// Returns true if the input date falls within the EDT period.
bool IsEDT(datetime date)
{
    MqlDateTime dt;
    TimeToStruct(date, dt);
    int year = dt.year;
    // StringToTime() is used to convert the string date to a datetime value.
    // TimeToStruct() is then used to convert the datetime to an MqlDateTime structure.
    // We then check the day_of_week field of the MqlDateTime structure.
    datetime edtStart = StringToTime(StringFormat("%d.03.%d 02:00", GetSecondSundayOfMonth(year, 3), year));
    datetime edtEnd = StringToTime(StringFormat("%d.11.%d 02:00", GetFirstSundayOfMonth(year, 11), year));
    
    return (date >= edtStart && date < edtEnd);
}

// Finds the second Sunday of a given month and year.
// Used to determine the start of EDT.
int GetSecondSundayOfMonth(int year, int month)
{
    for(int day = 8; day <= 14; day++)
    {
        datetime dt = StringToTime(StringFormat("%d.%02d.%d", year, month, day));
        MqlDateTime mdt;
        TimeToStruct(dt, mdt);
        if(mdt.day_of_week == 0)
            return day;
    }
    return 0;
}

// Finds the first Sunday of a given month and year.
// Used to determine the end of EDT.
int GetFirstSundayOfMonth(int year, int month)
{
    for(int day = 1; day <= 7; day++)
    {
        datetime dt = StringToTime(StringFormat("%d.%02d.%d", year, month, day));
        MqlDateTime mdt;
        TimeToStruct(dt, mdt);
        if(mdt.day_of_week == 0)
            return day;
    }
    return 0;
}





//--- START function related to checking times


// likely to be called twice
bool is_around_est_00am_close_time()
{
    bool is_around = false;
    datetime currentEasternTime = GetCurrentEasternTime();            

    MqlDateTime dt;
    TimeToStruct(currentEasternTime, dt);
    
    // check 2 times at 00:00 
    if (dt.hour == 00 && dt.min < 15)
       is_around = true;  

    
    if(is_around)
    {
       // Print("is_around_est_00am_close_time::Current Eastern Time: ", TimeToString(currentEasternTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS));            
    }
    return is_around;   
}


bool is_after_00am_and_before_17pm_est()
{
    bool is_around = false;
    datetime currentEasternTime = GetCurrentEasternTime();            
    MqlDateTime dt;
    TimeToStruct(currentEasternTime, dt);    
    
    if (dt.hour >= 00 && dt.hour <= 16)
       is_around = true;
    // ignore midnight     
    if (dt.hour == 00 && dt.min == 00)
       is_around = false;  
    
    if(is_around)
    {
        //Print("is_after_00am_and_before_17pm_est::Current Eastern Time: ", TimeToString(currentEasternTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS));            
    }
    return is_around;   
}


bool is_about_935am_est()
{
    bool is_around = false;
    datetime currentEasternTime = GetCurrentEasternTime();            
    MqlDateTime dt;
    TimeToStruct(currentEasternTime, dt);    
    
    if (dt.hour == 9 && dt.min == 35)
       is_around = true;        
    return is_around;   
}

bool is_about_x_minute_after930_est(int x)
{    
    bool is_around = false;
    datetime currentEasternTime = GetCurrentEasternTime();            
    MqlDateTime dt;
    TimeToStruct(currentEasternTime, dt);    
    int x_minute_after_930 = 30 + x;
    //if (dt.hour == 9) {      
      //Print("dt.hour", dt.hour);
      //Print("x_minute_after_930: ", x_minute_after_930);
      //Print("dt.min", dt.min);
    //}
    //Print("x_minute_after_930: ",x_minute_after_930);
    //Print("dt.hour ", dt.hour );
    if (dt.hour == 9 && dt.min == x_minute_after_930) {
       is_around = true;       
       //Print("is_about_x_minute_after930_est dt.min ", dt.min );
    }
    
    return is_around;   
}

// eod
bool is_about_1559_est()
{    
    bool is_around = false;
    datetime currentEasternTime = GetCurrentEasternTime();            
    MqlDateTime dt;
    TimeToStruct(currentEasternTime, dt);    
    
    if (dt.hour == 15 && dt.min == 59)
       is_around = true;        
    return is_around;   
}
bool is_about_1130_est()
{    
    bool is_around = false;
    datetime currentEasternTime = GetCurrentEasternTime();            
    MqlDateTime dt;
    TimeToStruct(currentEasternTime, dt);    
    
    if (dt.hour == 10 && dt.min == 00)
       is_around = true;        
    return is_around;   
}


bool is_about_17pm_est()
{
    bool is_around = false;
    datetime currentEasternTime = GetCurrentEasternTime();            
    MqlDateTime dt;
    TimeToStruct(currentEasternTime, dt);    
    
    if (dt.hour == 17 && dt.min == 00)
       is_around = true;        
    return is_around;   
}




bool is_est_16pm_close_time()
{
    datetime currentEasternTime = GetCurrentEasternTime();        
    if(IsAround16pmEST(currentEasternTime))
    {
        Print("IsAround16pmEST::Current Eastern Time: ", TimeToString(currentEasternTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS));        
        return true;
    }
    else
    {      
        return false;
    }
}

bool is_est_11am_close_time()
{
    datetime currentEasternTime = GetCurrentEasternTime();        
    if(IsAround11amEST(currentEasternTime))
    {
        Print("IsAround11amEST::Current Eastern Time: ", TimeToString(currentEasternTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS));        
        return true;
    }
    else
    {      
        return false;
    }
}






bool IsBetween2150And2210(datetime time)
{
    MqlDateTime dt;
    TimeToStruct(time, dt);
    
    if (dt.hour == 21 && dt.min >= 50)
        return true;
    if (dt.hour == 22 && dt.min <= 10)
        return true;
    
    return false;
}


bool IsBetween2150And2300(datetime time)
{
    MqlDateTime dt;
    TimeToStruct(time, dt);
    
    if (dt.hour == 21 && dt.min >= 50)
        return true;
    if (dt.hour == 22)
        return true;
    
    return false;
}

bool IsBetween2200And2300(datetime time)
{
    MqlDateTime dt;
    TimeToStruct(time, dt);
    return dt.hour == 22;
}


bool IsBetween2205And2300(datetime time)
{
     MqlDateTime dt;
    TimeToStruct(time, dt);
    
    if (dt.hour == 22 && dt.min >= 05)
        return true;    
    
    return false;
}


bool IsBetween1005And1100(datetime time)
{
     MqlDateTime dt;
    TimeToStruct(time, dt);
    
    if (dt.hour == 10 && dt.min >= 05)
        return true;    
    
    return false;
}
bool IsBetween1010And1100(datetime time)
{
     MqlDateTime dt;
    TimeToStruct(time, dt);
    
    if (dt.hour == 10 && dt.min >= 10)
        return true;    
    
    return false;
}


bool IsBetween1010And1105(datetime time)
{
     MqlDateTime dt;
    TimeToStruct(time, dt);
    
    if (dt.hour == 10 && dt.min >= 10)
        return true;    
    
    if (dt.hour == 11 && dt.min <= 5)
        return true;    
    
    return false;
}

bool IsBetween1006And1103(datetime time)
{
     MqlDateTime dt;
    TimeToStruct(time, dt);
    
    if (dt.hour == 10 && dt.min >= 6)
        return true;    
    
    if (dt.hour == 11 && dt.min <= 3)
        return true;    
    
    return false;
}



bool IsAround11amEST(datetime time)
{
    MqlDateTime dt;
    TimeToStruct(time, dt);
    
    if (dt.hour == 11 && dt.min <= 10)
        return true;    
    
    return false;
}

bool IsAround16pmEST(datetime time)
{
    MqlDateTime dt;
    TimeToStruct(time, dt);
    
    if (dt.hour == 16 && dt.min <= 10)
        return true;    
    
    return false;
}


//--- END function related to checking times

// https://claude.ai/chat/299e8c17-08b4-413e-b988-143b625bd86b
//datetime specificDate = D'2024.07.10'; // Year.Month.Day   
//if (IsH1OnDate(specificDate))
// {
//    Print("Current H1 candle is on the specified date: ", TimeToString(specificDate, TIME_DATE));
    // Add your trading logic here
// }
bool IsH1OnDate(datetime targetDate)
{
   datetime currentCandleTime = iTime(_Symbol, PERIOD_H1, 0);
   return (TimeToString(currentCandleTime, TIME_DATE) == TimeToString(targetDate, TIME_DATE));
}


string GetCurrentD1Date(datetime d1CandleFromITime)
{
  // datetime d1CandleTime = iTime(_Symbol, PERIOD_D1, 0);
   MqlDateTime dt;
   TimeToStruct(d1CandleFromITime, dt);
   
   return StringFormat("D'%04d.%02d.%02d'", 
      dt.year,
      dt.mon,
      dt.day);
}

// sample if (currentDate == "D'2024.07.10'") 
string GetPreviousD1Date()
{
   datetime d1CandleTime = iTime(_Symbol, PERIOD_D1, 1);   
   MqlDateTime dt;
   TimeToStruct(d1CandleTime, dt);
   
   return StringFormat("D'%04d.%02d.%02d'", 
      dt.year,
      dt.mon,
      dt.day);
}


// 1.find datetime correcsponding to most recent 00:00 Estern time 
// 2. using that datetime in iBarShift to get the open price of most recent 00:00 Estern time 
// note: using 1min timeframe to get the most recent 00:00 Estern time
// Warning: might be wrong
double get_est_00am_open_price(string symbol)
{
    datetime currentEasternTime = GetCurrentEasternTime();            
    MqlDateTime dt;
    TimeToStruct(currentEasternTime, dt);
    
    datetime est_00am = StringToTime(StringFormat("%04d.%02d.%02d 00:00", dt.year, dt.mon, dt.day));
    Print("get_est_00am_open_price est_00am:", est_00am);
    int shift = iBarShift(symbol, PERIOD_M1, est_00am, true);
    double open_price = iOpen(symbol, PERIOD_M1, shift);
    return open_price;
}

double get_est_930am_open_price(string symbol, int x_minutes)
{
    datetime currentEasternTime = GetCurrentEasternTime();            
    MqlDateTime dt;
    TimeToStruct(currentEasternTime, dt);
    
    datetime est_930am = StringToTime(StringFormat("%04d.%02d.%02d 09:30", dt.year, dt.mon, dt.day));
    datetime est_930am_server_time = convert_estern_time_to_server_time(est_930am);
    int shift = iBarShift(symbol, PERIOD_M1, est_930am_server_time, true);
    if(shift == -1) {
        Print("get_est_930am_open_price Error: No bar found at::", TimeToString(est_930am), " ", symbol);
        return -1; // Return -1 if no bar exists (e.g., market closed)
    }
    double open_price = iOpen(symbol, PERIOD_M1, shift);
    //double open_price = iOpen(symbol, PERIOD_M1, x_minutes - 1);
    Print("open_price ", open_price, " at server time ", est_930am_server_time);
    return open_price;
}



// Function to get the closing price x minutes after 9:30 AM EST for a given symbol
// Parameters:
//   symbol: Trading instrument (e.g., "QQQ")
//   x_minutes: Number of minutes after 9:30 AM (e.g., 5 for 9:34 AM, 15 for 9:44 AM) because each minute from 9:30 which similar to index base
// Returns: Close price at the specified time, or -1 if an error occurs
double get_close_price_at_x_minutes_after_930(string symbol, int x_minutes)
{
    // Ensure x_minutes is non-negative to avoid invalid times
    if(x_minutes < 0) {
        Print("Error: x_minutes cannot be negative (", x_minutes, ")");
        return -1;
    }
    
    // Get the current time in Eastern Standard Time (EST)
    datetime currentEasternTime = GetCurrentEasternTime();
    
    // Convert current EST time to a structure to extract year, month, day
    MqlDateTime dt;
    TimeToStruct(currentEasternTime, dt);
    
    // Calculate the target time: 9:30 AM + x_minutes
    // Add x_minutes to 9:30 AM (9:30 = 9 hours, 30 minutes)
    int target_hour = 9;
    int target_minute = 30 + x_minutes - 1;
    
    // Handle minute overflow (e.g., 65 minutes = 1 hour 5 minutes)
    target_hour += target_minute / 60;      // Add extra hours from minutes
    target_minute = target_minute % 60;     // Get remaining minutes
    
    // Ensure the hour is within valid range (0-23)
    if(target_hour >= 24) {
        Print("Error: Target time exceeds 24 hours (", x_minutes, " minutes after 9:30)");
        return -1;
    }
    
    // Format the target time as "YYYY.MM.DD HH:MM" (e.g., "2025.03.27 09:35")
    datetime x_minutes_after_930_est = StringToTime(StringFormat("%04d.%02d.%02d %02d:%02d", 
                                                            dt.year, dt.mon, dt.day, 
                                                            target_hour, target_minute));
    datetime x_minutes_after_930_server_time = convert_estern_time_to_server_time(x_minutes_after_930_est);
    // Find the bar index (shift) for this exact time on the M1 timeframe
    // true ensures an exact match for the timestamp
    int shift = iBarShift(symbol, PERIOD_M1, x_minutes_after_930_server_time, true);
    if(shift == -1) {
        Print("Error: No bar found at ", TimeToString(x_minutes_after_930_server_time), " ", symbol);
        return -1; // Return -1 if no bar exists (e.g., market closed)
    }
    
    // Retrieve the closing price for the bar at the specified shift
    double close_price = iClose(symbol, PERIOD_M1, shift);
    if(close_price == 0) {
        Print("Error: Failed to retrieve close price at ", TimeToString(x_minutes_after_930_server_time), " EST");
        return -1; // Return -1 if price retrieval fails
    }
    Print("close_price: " ,close_price, " at server time " ,  x_minutes_after_930_server_time);
    // Return the valid closing price
    return close_price;
}


// knowing that serverTime is different to estern time
// we want to find out what is the corresponding server time if Estern time is 00:00
datetime get_est_00am_server_time()
{
    datetime currentEasternTime = GetCurrentEasternTime();            
    MqlDateTime dt;
    TimeToStruct(currentEasternTime, dt);
    
    datetime est_00am = StringToTime(StringFormat("%04d.%02d.%02d 00:00", dt.year, dt.mon, dt.day));
    datetime server_time = convert_estern_time_to_server_time(est_00am);
    return server_time;
}

double get_open_price_at_server_time(string symbol, datetime server_time)
{    
    int shift = iBarShift(symbol, PERIOD_M1, server_time, true);
    double open_price = iOpen(symbol, PERIOD_M1, shift);
    return open_price;
}

bool is_after_10am_and_before_1130am_est()
{    
    datetime currentEasternTime = GetCurrentEasternTime();            
    MqlDateTime dt;
    TimeToStruct(currentEasternTime, dt);    
    
    if (dt.hour == 11 && dt.min <= 30)
       return true;  
    if (dt.hour == 10)
       return true;    
    
    return false;        
}

bool is_after_2am_and_before_4am_est()
{    
    datetime currentEasternTime = GetCurrentEasternTime();            
    MqlDateTime dt;
    TimeToStruct(currentEasternTime, dt);    
    
    if (dt.hour >= 7 && dt.hour < 12)
       return true;      
    
    return false;        
}
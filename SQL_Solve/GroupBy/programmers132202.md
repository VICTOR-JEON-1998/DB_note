# programmers132202

**Problem Link**  
[Link to problem ](https://school.programmers.co.kr/learn/courses/30/lessons/132202)

---

## Tip of the solve
When using GROUP BY,
if you need conditional query,
use WHERE before GROUP BY or HAVING after GROUP BY

and you can extract only specific time like year or month, 
you can make it just by using YEAR(column) MONTH(column).   


---

## My solution query
```sql
SELECT MCDP_CD AS '진료과 코드', COUNT(APNT_NO) AS '5월예약건수'
FROM APPOINTMENT 
WHERE YEAR(APNT_YMD) = 2022
AND MONTH(APNT_YMD) = 5
GROUP BY MCDP_CD
ORDER BY COUNT(APNT_NO), MCDP_CD

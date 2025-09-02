# Find aniaml which 'el' in name

**Problem Link**  
[Link to problem ](https://school.programmers.co.kr/learn/courses/30/lessons/59047?language=oracle)

---

## Explain the problem
Find animals which name includes 'el'
The point is WHERE - AND using and ORDER BY.
Also find some srting condition regardless Upper / Lower


---

## My solution query
```sql
--
SELECT ANIMAL_ID, NAME
FROM ANIMAL_INS
WHERE (UPPER(NAME) LIKE UPPER('%el%')) AND ANIMAL_TYPE LIKE 'Dog'
ORDER BY NAME

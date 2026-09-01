package com.ganesh.IKR.repository;
import com.ganesh.IKR.entity.PaperOrder;
import org.springframework.data.jpa.repository.JpaRepository;
import java.time.OffsetDateTime; import java.util.List;
public interface PaperOrderRepository extends JpaRepository<PaperOrder, Long> {
    long countByUserIdAndStatusAndCreatedAtGreaterThanEqual(Long userId, String status, OffsetDateTime from);
    List<PaperOrder> findByUserIdOrderByCreatedAtDesc(Long userId);
}

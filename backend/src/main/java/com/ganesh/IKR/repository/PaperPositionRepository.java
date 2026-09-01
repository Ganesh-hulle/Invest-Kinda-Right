package com.ganesh.IKR.repository;
import com.ganesh.IKR.entity.PaperPosition;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional; import java.util.List;
public interface PaperPositionRepository extends JpaRepository<PaperPosition, Long> {
    Optional<PaperPosition> findByUserIdAndInstrumentToken(Long userId, Long instrumentToken);
    long countByUserIdAndQuantityGreaterThan(Long userId, Integer quantity);
    List<PaperPosition> findByUserIdOrderByTradingsymbolAsc(Long userId);
}
